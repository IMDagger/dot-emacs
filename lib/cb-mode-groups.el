;;; cb-mode-groups.el --- Configuration for ad-hoc mode groups

;; Copyright (C) 2013 Chris Barrett

;; Author: Chris Barrett <chris.d.barrett@me.com>
;; Version: 20130527.0043

;; This file is not part of GNU Emacs.

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Configuration for ad-hoc mode groups

;;; Code:

(defmacro define-combined-hook (name hooks)
  "Create a hook bound as NAME that is run after each hook in HOOKS."
  (declare (indent 1))
  `(progn
     ;; Define combined hook.
     (defvar ,name nil "Auto-generated combined hook.")
     ;; Add combined hook to each of the given hooks.
     (--each ,hooks
       (hook-fn it
         (run-hooks ',name)))))

(defmacro define-mode-group (name modes)
  "Create an ad-hoc relationship between language modes.
* Creates a special var with NAME to contain the grouping.
* Declares a hook NAME-hook that runs after any of MODES are initialized."
  (declare (indent 1))
  (let ((hook (intern (format "%s-hook" name))))
    `(progn
       ;; Define modes variable.
       (defconst ,name ,modes "Auto-generated variable for language grouping.")
       ;; Create a combined hook for MODES.
       (define-combined-hook ,hook
         (--map (intern (concat (symbol-name it) "-hook"))
                ,modes)))))

(define-mode-group cb:scheme-modes
  '(scheme-mode
    inferior-scheme-mode
    geiser-repl-mode
    geiser-mode))

(define-mode-group cb:clojure-modes
  '(clojure-mode
    clojurescript-mode))

(define-mode-group cb:elisp-modes
  '(emacs-lisp-mode
    ielm-mode))

(define-mode-group cb:slime-modes
  '(slime-mode
    slime-repl-mode))

(define-mode-group cb:lisp-modes
  `(,@cb:scheme-modes
    ,@cb:clojure-modes
    ,@cb:elisp-modes
    ,@cb:slime-modes
    common-lisp-mode
    inferior-lisp-mode
    lisp-mode
    repl-mode))

(define-mode-group cb:haskell-modes
  '(haskell-mode
    inferior-haskell-mode
    haskell-interactive-mode
    haskell-c-mode
    haskell-cabal-mode))

(define-mode-group cb:python-modes
  '(python-mode
    inferior-python-mode))

(define-mode-group cb:ruby-modes
  '(inf-ruby-mode
    ruby-mode))

(define-mode-group cb:rails-modes
  `(,@cb:ruby-modes
    erb-mode))

(define-mode-group cb:xml-modes
  '(sgml-mode
    nxml-mode))

(define-mode-group cb:org-minor-modes
  '(orgtbl-mode
    orgstruct-mode
    orgstruct++-mode))

(define-mode-group cb:prompt-modes
  '(comint-mode
    inf-ruby-mode
    inferior-python-mode
    ielm-mode
    erc-mode
    slime-repl-mode
    inferior-scheme-mode
    inferior-haskell-mode
    sclang-post-buffer-mode))

(defun cb:clear-scrollback ()
  "Erase all but the last line of the current buffer."
  (interactive)
  (let ((inhibit-read-only t)
        (last-line (save-excursion
                     (goto-char (point-max))
                     (forward-line -1)
                     (line-end-position))))
    (delete-region (point-min) last-line)
    (goto-char (point-max))))

(hook-fn 'cb:prompt-modes-hook
  (local-set-key (kbd "C-a") 'move-beginning-of-line)
  (local-set-key (kbd "C-e") 'move-end-of-line)
  (local-set-key (kbd "C-l") 'cb:clear-scrollback)
  (local-set-key (kbd "M->") 'cb:append-buffer)
  (cb:append-buffer))

(provide 'cb-mode-groups)

;; Local Variables:
;; lexical-binding: t
;; End:

;;; cb-mode-groups.el ends here