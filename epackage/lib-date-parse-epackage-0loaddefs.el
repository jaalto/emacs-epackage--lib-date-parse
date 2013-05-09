
;;;### (autoloads (date-parse-sort-fields date-parse-lessp date-parse-compare-key
;;;;;;  date-parse-year date-parse-month date-parse date-parse-default-date-list)
;;;;;;  "date-parse" "../date-parse.el" (20875 53212 0 0))
;;; Generated autoloads from ../date-parse.el

(autoload 'date-parse-default-date-list "date-parse" "\
Return DATE list.

\(fn DATE)" nil nil)

(autoload 'date-parse "date-parse" "\
Parse a DATE into a 3-list of year, month, day.
This list may be extended by the weekday,
and then by the hour, minute, second, and timezone
\(if such information is found), making a total of eight list elements.
Optional arg EXACTP means the whole string must hold the date.
Optional NODEFAULT means the date is not defaulted (to the current year).
In any case, if `date-parse' succeeds, variable `date-parse-indices' is set
to the 2-list holding the location of the date within the string.

\(fn DATE &optional EXACTP NODEFAULT)" nil nil)

(autoload 'date-parse-month "date-parse" "\
Parse MONTH.

\(fn MONTH)" nil nil)

(autoload 'date-parse-year "date-parse" "\
Parse YEAR.

\(fn YEAR)" nil nil)

(autoload 'date-parse-compare-key "date-parse" "\
Map DATE to strings preserving ordering.
If optional INTEGER-P is true, yield an integer instead of a string.
In that case, the granularity is minutes, not seconds,
and years must be in this century.

\(fn DATE &optional INTEGER-P)" nil nil)

(autoload 'date-parse-lessp "date-parse" "\
Compare DATE1 to DATE2 (which may be unparsed strings or parsed date lists).
Equivalent to (string< (date-parse-compare-key date1) (date-parse-compare-key date2)).

\(fn DATE1 DATE2)" nil nil)

(autoload 'date-parse-sort-fields "date-parse" "\
Sort lines in region by date value; argument means descending order.
Called from a program, there are three required arguments:
REVERSE (non-nil means reverse order), BEG and END (region to sort).

\(fn REVERSE BEG END)" t nil)

;;;***
(provide 'lib-date-parse-epackage-0loaddefs)
