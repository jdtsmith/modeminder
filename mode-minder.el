;;; mm.el --- Print graph of major and minor modes  -*- lexical-binding: t -*-
;; Copyright (C) 2022 JDS

;; Author: J.D. Smith <jdtsmith@gmail.com>
;; URL: https://github.com/jdtsmith/modeminder
;; Package-Requires: ((emacs "27.1"))
;; Version: 0.0.1
;; Keywords: modes

;; Usage: M-x mode-minder

;;; Code:
(require 'button)
(eval-when-compile
  (require 'cl-lib)
  (require 'seq))

(defvar mode-minder-ht (make-hash-table :test 'eq))
(defconst mode-minder-pad 36)

(defun mode-minder--describe-function (func)
  (let (help-xref-following) ; do not open locally
    (describe-function func)))

(define-button-type 'mode-minder-help-function
  :supertype 'help-xref
  'help-function 'mode-minder--describe-function
  'help-echo (purecopy "mouse-2, RET: describe this function"))

(defun mode-minder--sym-sort (a b)
  (string-lessp (downcase (symbol-name a)) (downcase (symbol-name b))))

(defun mode-minder--map-tree (mode children depth)
  (let* ((mstr (concat (make-string (* 2 depth) ?\s)
		       (if (= (% depth 2) 0) "•" "-") " "
		       (symbol-name mode)))
	 (pad (max 0 (- mode-minder-pad (length mstr)))))
    (princ mstr)
    (with-current-buffer standard-output
      (save-excursion
	(re-search-backward " \\([^ ]+\\)")
	(help-xref-button 1 'mode-minder-help-function mode)))
    (when (file-in-directory-p (symbol-file mode) package-user-dir)
      (princ "(P)")
      (setq pad (max 0 (- pad 3))))
    (princ (make-string pad ?\s))
    (if-let* ((doc (documentation mode))
	      (doc (substring doc 0 (string-match (rx (or (group ?. space) ?\n)) doc))))
	(princ (concat " " doc)))
    (princ "\n")
    (mapc (lambda (c) (mode-minder--map-tree c (gethash c mode-minder-ht) (1+ depth)))
	  (sort children #'mode-minder--sym-sort))))

(defvar mode-minder--warmed nil)
(defun mode-minder ()
  "Show heirarchy of all major and minor modes."
  (interactive)
  (clrhash mode-minder-ht)

  (unless mode-minder--warmed
    (message "Mode-Minder: Loading all mode libraries...")
    (mapatoms
     (lambda (x)
       (when-let (((and (commandp x) (string-suffix-p "-mode" (symbol-name x))))
		  (package (intern-soft (file-name-base (symbol-file x)))))
	 (condition-case nil (require package) (error nil)))))
    (setq mode-minder--warmed t)
    (message "Mode-Minder: Loading all mode libraries...done"))
  (with-help-window "*Modes*"
    (let (roots minors)
      (mapatoms
       (lambda (x)
	 (when (and (commandp x) (string-suffix-p "-mode" (symbol-name x)))
	   (if (memq x minor-mode-list) (push x minors)
	     (if-let ((parent (get x 'derived-mode-parent)))
		 (push x (gethash parent mode-minder-ht))
	       (push x roots))))))
      (cl-loop for list in
	       (append (mapcar #'cdr (seq-group-by (lambda (x) (null (gethash x mode-minder-ht))) roots))
		       (list minors))
	       for i upfrom 0 do
	       (princ (aref '["Major Mode Hierarchies:"
			      "\nStandalone Major Modes:"
			      "\nMinor Modes:"]
			    i))
	       (with-current-buffer standard-output
		 (add-text-properties (line-beginning-position) (point) '(font-lock-face info-title-2)))
	       (princ "\n\n")
	       (mapc (lambda (x) (mode-minder--map-tree x (gethash x mode-minder-ht) 0))
		     (sort list #'mode-minder--sym-sort))))))

(provide 'mode-minder)
;;; mode-minder.el ends here.