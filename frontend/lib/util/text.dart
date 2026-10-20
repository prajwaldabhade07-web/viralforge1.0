const _mon = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String plural(int n, String one, String many) => '$n ${n == 1 ? one : many}';

String verdictFor(int s) => s >= 90 ? 'Exceptional' : s >= 75 ? 'Strong' : s >= 60 ? 'Promising' : s >= 40 ? 'Developing' : 'Needs rework';

/// "+4 from last analysis", "-2 vs last week", or [same] when nothing changed.
String delta(int d, String tail, String same) => d == 0 ? same : '${d > 0 ? '+' : ''}$d $tail';

/// "2 Mar", or '' when the date is unknown.
String shortDate(DateTime? d) => d == null ? '' : '${d.day} ${_mon[d.month - 1]}';