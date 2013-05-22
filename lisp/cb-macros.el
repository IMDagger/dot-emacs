;;; cb-macros --- Common macros used in my emacs config.

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
                     (destructuring-bind (&optional arg1 arg2 arg3 arg4 arg5 arg6
                                                    arg7 arg8 arg9) args
                       ,@(cons docstring body)))))

(defmacro after (feature &rest body)
  "Execute BODY forms after FEATURE is loaded."
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

(defun cb:tree-replace (target rep tree)
  "Replace TARGET with REP in TREE."
  (cond ((equal target tree) rep)
        ((atom tree)         tree)
        (t
         (--map (cb:tree-replace target rep it) tree))))

(defmacro with-window-restore (&rest body)
  "Declare an action that will eventually restore window state.
The original state can be restored by calling (restore) in BODY."
  (declare (indent 0))
  (let ((register (cl-gensym)))
    `(progn
       (window-configuration-to-register ',register)
       ,@(cb:tree-replace '(restore)
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

(defmacro define-modal-file-viewer (file key-binding)
  "Visit FILE modally.  Window state is reverted after killing the buffer.
KEY-BINDING is used to globally show and kill the view."
  (let* ((file (eval file))
         (fname  (file-name-nondirectory (file-name-sans-extension file)))
         (command (intern (format "__%s-%s-viewer" fname (cl-gensym)))))
    `(progn
       (defun ,command ()
         ,(concat "Auto-generated modal file viewer for " file)
         (interactive)
         (with-window-restore
           (find-file ,file)
           (delete-other-windows)
           (local-set-key (kbd ,key-binding) (command (bury-buffer)
                                                      (restore)))))

       (bind-key ,key-binding ',command))))

(provide 'cb-macros)

;;; cb-macros.el ends here
