;;; date-parse.el --- Parse and sort dates

;; This file is not part of Emacs

;;{{{ Id

;; Copyright (C)    1989 John Rose
;; Copyright (C)    1992-2012 Jari Aalto
;; Author:          John Rose <rose@think.com>
;; Maintainer:      none
;; Packaged-by:     Jari Aalto
;; Created:         1989-03
;; Keywords:        extensions

;; This program is free software; you can redistribute it and/or modify it
;; under the terms of the GNU General Public License as published by the Free
;; Software Foundation; either version 2 of the License, or (at your option)
;; any later version.
;;
;; This program is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
;; or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
;; for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program. If not, see <http://www.gnu.org/licenses/>.
;;
;; Visit <http://www.gnu.org/copyleft/gpl.html> for more information

;;}}}
;;{{{ Install

;;; Install:

;;  This is a library and the functions are meant to be used in other
;;  lisp packages. The standard require statement is:
;;
;;      (require 'date-parse)
;;
;;      ;;  If this file exists, it can be used instead of the bove.
;;      ;;  The file containst autoload forward declarations
;;      (require 'date-parse-autoload)

;;}}}
;;{{{ Commentary

;;; Commentary:

;;  Preface, 1989
;;
;;      Hacks for reading dates. Something better needs to be done,
;;      obviously. In the file "dired-sort" are dired commands for
;;      reordering the buffer by modification time, which is the whole
;;      purpose of this exercise.
;;
;;}}}

;;; Change Log:

;;; Code:

(require 'cl-compat) ;; setnth

(eval-when-compile
  ;; plusp, minusp
  ;; eql (in 22.x this is C-primitive)
  (require 'cl))

(eval-and-compile
  (autoload 'sort-subr "sort"))

;;; ....................................................... &variables ...

(defvar date-parse-indices nil
  "List of (START END) from last successful call to date-parse.")

(defconst date-parse-patterns
  '(( ;; Sep 29 12:09:55 1986
     "[ \t]*\\([A-Za-z]+\\)[. \t]+\\([0-9]+\\)[, \t]+\
\\([0-9]+\\):\\([0-9]+\\):\\([0-9]+\\)[, \t]+\
\\([0-9]+\\)[ \t]*"
     6 1 2 nil 3 4 5)
    ( ;; Sep 29 12:09
     "[ \t]*\\([A-Za-z]+\\)[. \t]+\\([0-9]+\\)[, \t]+\
\\([0-9]+\\):\\([0-9]+\\)[ \t]*"
     nil 1 2 nil 3 4)
    ( ;; Sep 29 1986
     "[ \t]*\\([A-Za-z]+\\)[. \t]+\\([0-9]+\\)[, \t]+\
\\([0-9]+\\)[ \t]*"
     3 1 2)
    ( ;; Sep 29
     "[ \t]*\\([A-Za-z]+\\)[. \t]+\\([0-9]+\\)[ \t]*"
     nil 1 2)
    ( ;; 2004-10-14 17:23
     "^[ \t]*\\([0-9][0-9][0-9][0-9]\\)-\\([0-9][0-9]\\)-\\([0-9][0-9]\\)[ \t]+\
\\([0-9][0-9]\\):\\([0-9][0-9]\\)"
     1 2 3 nil 4 5))
  "List of (regexp field field ...), each parsing a different style of date.
The fields locate, in order:

  1. the year
  2. month
  3. day
  4. weekday,
  5. hour
  6. minute
  7. second
  8. and timezone of the date.

Any or all can be null, and the list can be short. Each field is nil,
an integer referring to a regexp field, or a 2-list of an integer and
a string-parsing function which is applied (instead of a default) to
the field string to yield the appropriate integer value.")

;;; ............................................................ &code ...

;; FIXME: Yuck. We only default the year.
;;;###autoload
(defun date-parse-default-date-list (date)
  "Return DATE list."
  (let ((now nil))
    ;; If the year is missing, default it to this year or last year,
    ;; whichever is closer.
    (or (nth 0 date)
        (let ((year (nth 0 (or now (setq now (date-parse "now" t t)))))
              (diff (* 30 (- (nth 1 date) (nth 1 now)))))
          (if (zerop diff)
              (setq diff (- (nth 2 date) (nth 2 now))))
          (if (> diff 7)
              (setq year (1- year)))
          (setnth 0 date year)))
    date))

;;;###autoload
(defun date-parse (date &optional exactp nodefault)
  "Parse a DATE into a 3-list of year, month, day.
This list may be extended by the weekday,
and then by the hour, minute, second, and timezone
\(if such information is found), making a total of eight list elements.
Optional arg EXACTP means the whole string must hold the date.
Optional NODEFAULT means the date is not defaulted (to the current year).
In any case, if `date-parse' succeeds, variable `date-parse-indices' is set
to the 2-list holding the location of the date within the string."
  (if (not (stringp date))
      date
    (let ((ptr date-parse-patterns)
          (string date)
          start end)
      (and (or (string= string "now")
               (string= string "today"))
           (setq string (current-time-string)
                 exactp nil))
      (setq date nil)
      (while ptr
        (let ((pat (car (car ptr)))
              (fields (cdr (car ptr))))
          (if (setq start (string-match pat string))
              (setq end (match-end 0)))
          (and start
               exactp
               (or (plusp start)
                   (< end (length string)))
               (setq start nil))
          (setq ptr (cdr ptr))
          (if start
              ;; First extract the strings,
              ;; and decide which parsers to call.
              ;; At this point, the pattern can still fail
              ;; if a parser returns nil.
              (let ((strs nil)
                    (fns nil)
                    (default-fns
                      '(date-parse-year
                        date-parse-month
                        nil ;;day
                        date-parse-weekday
                        nil nil nil ;;hhmmss
                        date-parse-timezone)))
                (while fields
                  (let ((field (car fields))
                        (fn (car default-fns)))
                    (setq fields (cdr fields)
                          default-fns (cdr default-fns))
                    ;; Allow field to be either 3 or (3 string-to-int)
                    (if (listp field)
                        (setq field (car field)
                              fn (car (cdr field))))
                    (setq strs
                          (cons
                           (cond
                            ((null field) nil)
                            ((integerp field)
                             (substring
                              string
                              (match-beginning field)
                              (match-end field)))
                            (t field))
                           strs))
                    (setq fns (cons (or fn 'string-to-int) fns))))
                ;; Now parse them:
                (setq strs (nreverse strs)
                      fns (nreverse fns))
                (setq date strs) ;; Will replace cars.
                (while strs
                  (if (car strs)
                      (setcar strs
                              (or (funcall (car fns) (car strs))
                                  (setq date nil strs nil))))
                  (setq strs (cdr strs) fns (cdr fns)))
                ;; Break the while?
                (if date
                    (setq ptr nil))))))
      (or nodefault
          (null date)
          (setq date (date-parse-default-date-list date)))
      (if date
          (setq date-parse-indices (list start end)))
      date)))

;; Date field parsers:

;;;###autoload
(defun date-parse-month (month)
  "Parse MONTH."
  (if (not (stringp month))
      month
    (let ((sym 'date-parse-month-obarray))
      ;; This guy's memoized:
      (or (boundp sym) (set sym nil))
      (setq sym (intern month
                        (or (symbol-value sym)
                            (set sym (make-vector 51 0)))))
      (or (boundp sym)
          (let ((try nil)
                (key (downcase month)))
            (or try
                (plusp (setq try (string-to-int month)))
                (setq try nil))
            (or try
                (let ((ptr '("january" "february" "march" "april"
                             "may" "june" "july" "august"
                             "september" "october" "november" "december"))
                      (idx 1))
                  (while ptr
                    (if (eql 0 (string-match key (car ptr)))
                        (setq try idx ptr nil)
                      (setq idx (1+ idx) ptr (cdr ptr))))))
            (or try
                (if (string= key "jly")
                    (setq try 7)))
            (and try
                 (or (> try 12)
                     (< try 1))
                 (setq try nil))
            (set sym try)))
      (symbol-value sym))))

;;;###autoload
(defun date-parse-year (year)
  "Parse YEAR."
  (if (not (stringp year))
      year
    (setq year (string-to-int year))
    (cond
     ((> year 9999) nil)
     ((<= year 0) nil)
     ((> year 100) year)
     (t (+ year 1900)))))

;; Other functions:

;;;###autoload
(defun date-parse-compare-key (date &optional integer-p)
  "Map DATE to strings preserving ordering.
If optional INTEGER-P is true, yield an integer instead of a string.
In that case, the granularity is minutes, not seconds,
and years must be in this century."
  (or (consp date) (setq date (date-parse date)))
  (let ((year (- (nth 0 date) 1900))
        (month (- (nth 1 date) 1))
        (day (- (nth 2 date) 1))
        (hour (or (nth 4 date) 0))
        (minute (or (nth 5 date) 0))
        (second (or (nth 6 date) 0)))
    (if integer-p
        (+ (* (+ (* year 366) (* month 31) day)
              (* 24 60))
           (* hour 60)
           minute)
      ;; Else yield a string, which encodes everything:
      (let* ((sz (zerop second))
             (mz (and sz (zerop minute)))
             (hz (and mz (zerop hour)))
             (fmt
              (cond
               ((minusp year)
                (setq year (+ year 1900))
                (cond (hz "-%04d%c%c")
                      (mz "-%04d%c%c%c")
                      (sz "-%04d%c%c%c%02d")
                      (t "-%04d%c%c%c%02d%02d")))
               ((> year 99)
                (setq year (+ year 1900))
                (cond (hz "/%04d%c%c")
                      (mz "/%04d%c%c%c")
                      (sz "/%04d%c%c%c%02d")
                      (t "/%04d%c%c%c%02d%02d")))
               (hz "%02d%c%c")
               (mz "%02d%c%c%c")
               (sz "%02d%c%c%c%02d")
               (t "%02d%c%c%c%02d%02d"))))
        (setq month (+ month ?A) day (+ day ?a))
        (setq hour (+ hour ?A))
        (format fmt year month day hour minute second)))))

;;;###autoload
(defun date-parse-lessp (date1 date2)
  "Compare DATE1 to DATE2 (which may be unparsed strings or parsed date lists).
Equivalent to (string< (date-parse-compare-key date1) (date-parse-compare-key date2))."
  (or (consp date1) (setq date1 (date-parse date1)))
  (or (consp date2) (setq date2 (date-parse date2)))
  (catch 'return
    (let ((check (function (lambda (n1 n2)
                             (or n1 (setq n1 0))
                             (or n2 (setq n2 0))
                             (cond ((< n1 n2) (throw 'return t))
                                   ((> n1 n2) (throw 'return nil)))))))
      (funcall check (nth 0 date1) (nth 0 date2))
      (funcall check (nth 1 date1) (nth 1 date2))
      (funcall check (nth 2 date1) (nth 2 date2))
      (funcall check (nth 4 date1) (nth 4 date2))
      (funcall check (nth 5 date1) (nth 5 date2))
      (funcall check (nth 6 date1) (nth 6 date2))
      nil)))

;;;###autoload
(defun date-parse-sort-fields (reverse beg end)
  "Sort lines in region by date value; argument means descending order.
Called from a program, there are three required arguments:
REVERSE (non-nil means reverse order), BEG and END (region to sort)."
  (interactive "P\nr")
  (save-restriction
    (narrow-to-region beg end)
    (goto-char (point-min))
    (sort-subr
     reverse 'forward-line 'end-of-line
     (function
      (lambda ()
        (date-parse-compare-key
         (or (date-parse
              (buffer-substring (point) (progn (end-of-line) (point))))
             (throw 'key nil))))))))

(provide 'date-parse)

;;; date-parse.el ends here
