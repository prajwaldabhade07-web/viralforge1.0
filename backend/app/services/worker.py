"""In-process background worker backed by the persistent `analysis_jobs` table.
Jobs survive restarts: stale `processing` rows are recovered by `claim_next_job` after the lease."""
import logging
import threading

from app.container import Container
from app.services.pipeline import AnalysisPipeline

log = logging.getLogger("viralforge.worker")


class Worker:
    def __init__(self, container: Container):
        self.c = container
        self.pipeline = AnalysisPipeline(container.settings, container.repo, container.storage, container.gemini)
        self._stop = threading.Event()
        self._thread: threading.Thread | None = None

    def run_once(self) -> bool:
        if not self.c.refresh_model_status(max_age=60).ok:
            return False  # do not claim work we cannot do; jobs stay queued
        job = self.c.repo.claim_next_job(self.c.settings.job_lease_seconds)
        if not job:
            return False
        self.pipeline.process(job)
        return True

    def _loop(self):
        log.info("Analysis worker started")
        while not self._stop.is_set():
            try:
                busy = self.run_once()
            except Exception:  # noqa: BLE001
                log.exception("Worker iteration failed")
                busy = False
            if not busy:
                self._stop.wait(self.c.settings.worker_poll_seconds)
        log.info("Analysis worker stopped")

    def start(self):
        self._thread = threading.Thread(target=self._loop, name="analysis-worker", daemon=True)
        self._thread.start()

    def stop(self):
        self._stop.set()
        if self._thread:
            self._thread.join(timeout=5)
