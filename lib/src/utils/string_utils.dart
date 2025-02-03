String simpleDateFormatter(DateTime date) =>
    '${date.year}-${date.month >= 10 ? date.month : '0${date.month}'}-${date.day >= 10 ? date.day : '0${date.day}'}';
