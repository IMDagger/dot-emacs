;;; cb-lib --- Common macros used in my emacs config.

;; Copyright (C) 2013 Chris Barrett

;; Author: Chris Barrett <chris.d.barrett@me.com>

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 2, or (at
;; your option) any later version.

;; This program is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;;; Commentary:

;; Common macros used in my emacs config.

;;; Code:

(require 'dash)
(require 'cl-lib)

(defmacro hook-fn (hook &optional docstring &rest body)
  "Execute forms when a given hook is called.
The arguments passed to the hook function are bound to the symbol 'args'.

* HOOK is the name of the hook.

* DOCSTRING optionally documents the forms.  Otherwise, it is
  evaluated as part of BODY.

* BODY is a list of forms to evaluate when the hook is run.
The arguments to the hook are bound to 'arg1', 'arg2'.. 'arg9'.
The entire argument list is bound to 'args'."
  (declare (indent 1) (doc-string 2))
  `(add-hook ,hook (lambda (&rest args)
                     ,@(cons docstring body))))

(defmacro after (feature &rest body)
  "Like `eval-after-load' - once FEATURE is loaded execute the BODY."
  (declare (indent 1))
  `(eval-after-load ,feature '(progn ,@body)))

(defmacro command (&rest body)
  "Declare an `interactive' command with BODY forms.
The arguments are bound as 'args', with individual arguments bound to a0..a9"
  `(lambda (&rest args)
     (interactive)
     (destructuring-bind
         (&optional a0 a1 a2 a3 a4 a5 a6 a7 a8 a9)
         args
       ,@body)))

;;; ----------------------------------------------------------------------------

(defun directory-p (f)
  "Test whether F is a directory.  Return nil for '.' and '..'."
  (and (file-directory-p f)
       (not (string-match "/[.]+$" f))))

(defun directory-subfolders (path)
  "Return a flat list of all subfolders of PATH."
  (->> (directory-files path)
    (--map (concat path it))
    (-filter 'directory-p)))

(defun cb:prepare-load-dir (dir add-path)
  "Create directory DIR if it does not exist.
If ADD-PATH is non-nil, add DIR and its children to the load-path."
  (let ((dir (concat user-emacs-directory dir)))
    (unless (file-exists-p dir) (make-directory dir))
    (when add-path
      (--each (cons dir (directory-subfolders dir))
        (add-to-list 'load-path it)))
    dir))

(defmacro define-path (sym path &optional add-path)
  "Define a subfolder of the `user-emacs-directory'.
SYM is declared as a special variable set to PATH.
This directory tree will be added to the load path if ADD-PATH is non-nil."
  `(defconst ,sym (cb:prepare-load-dir ,path ,add-path)))

;;; ----------------------------------------------------------------------------

(defun tree-replace (target rep tree)
  "Replace TARGET with REP in TREE."
  (cond ((equal target tree) rep)
        ((atom tree)         tree)
        (t
         (--map (tree-replace target rep it) tree))))

(defmacro with-window-restore (&rest body)
  "Declare an action that will eventually restore window state.
The original state can be restored by calling (restore) in BODY."
  (declare (indent 0))
  (let ((register (cl-gensym)))
    `(progn
       (window-configuration-to-register ',register)
       ,@(tree-replace '(restore)
                          `(jump-to-register ',register)
                          body))))

(defmacro* declare-modal-view (command &optional (quit-key "q"))
  "Advise a given command to restore window state when finished."
  `(defadvice ,command (around
                        ,(intern (format "%s-wrapper" command))
                        activate)
     "Auto-generated window restoration wrapper."
     (with-window-restore
       ad-do-it
       (delete-other-windows)
       (local-set-key (kbd ,quit-key) (command (kill-buffer) (restore))))))

(defmacro* declare-modal-executor
    (name &optional &key command bind restore-bindings)
  "Execute a command with modal window behaviour.

* NAME is used to name the executor.

* COMMAND is a function or sexp to evaluate.

* KEY-BINDING is used to globally invoke the command.

* RESTORE-BINDINGS are key commands that will restore the buffer
state.  If none are given, KEY-BINDING will be used as the
restore key."
  (declare (indent defun))
  (let ((fname (intern (format "executor:%s" name))))
    `(progn
       (defun ,fname ()
         ,(format "Auto-generated modal executor for %s" name)
         (interactive)
         (with-window-restore
           ;; Evaluate the command.
           (cond ((interactive-form ',command) (call-interactively ',command))
                 ((functionp ',command)        (funcall ',command))
                 (t                            (eval ',command)))
           (delete-other-windows)
           ;; Configure restore bindings.
           (--each (or ,restore-bindings (list ,bind))
             (local-set-key (kbd it) (command (bury-buffer) (restore))))))

       (global-set-key (kbd ,bind) ',fname))))

(defun cb:truthy? (sym)
  "Test whether SYM is bound and non-nil."
  (and (boundp sym) (eval sym)))

(defun byte-compile-conf ()
  "Recompile all configuration files."
  (interactive)
  (byte-recompile-file (concat user-emacs-directory "init.el") t 0)
  (byte-recompile-directory cb:lib-dir 0 t)
  (byte-recompile-directory cb:lisp-dir 0 t))

(provide 'cb-lib)

;; Local Variables:
;; lexical-binding: t
;; End:

;;; cb-lib.el ends here