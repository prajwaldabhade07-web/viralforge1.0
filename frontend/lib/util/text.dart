const _mon = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String plural(int n, String one, String many) => '$n ${n == 1 ? one : many}';

String verdictFor(int s) => s >= 90 ? 'Exceptional' : s >= 75 ? 'Strong' : s >= 60 ? 'Promising' : s >= 40 ? 'Developing' : 'Needs rework';

/// One plain sentence that says what a score means and what to do.
String verdictHelp(int s) => s >= 90
    ? 'Outstanding. Post it with confidence.'
    : s >= 75
        ? 'Strong. Small tweaks could make it even better.'
        : s >= 60
            ? 'A solid base. A few fixes could make a big difference.'
            : s >= 40
                ? 'Needs work. Start with the first fix below.'
                : 'Not ready yet. Follow the fixes below, then try again.';

/// What each skill score means, in everyday words.
const skillHelp = {
  'hook': 'How well the first two seconds make people stop scrolling.',
  'engagement': 'How clear, interesting and useful it is while it plays.',
  'retention': 'How likely people are to watch until the end.',
  'shareability': 'How likely people are to send it to a friend.',
};

/// "+4 from last analysis", "-2 vs last week", or [same] when nothing changed.
String delta(int d, String tail, String same) => d == 0 ? same : '${d > 0 ? '+' : ''}$d $tail';

/// "2 Mar", or '' when the date is unknown.
String shortDate(DateTime? d) => d == null ? '' : '${d.day} ${_mon[d.month - 1]}';