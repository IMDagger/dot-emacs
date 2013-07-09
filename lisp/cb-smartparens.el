;;; cb-smartparens.el --- Configuration for Smartparens

;; Copyright (C) 2013 Chris Barrett

;; Author: Chris Barrett <chris.d.barrett@me.com>
;; Version: 20130708.0124

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

;; Configuration for Smartparens

;;; Code:

(require 'use-package)
(require 'dash)
(require 'cb-lib)

(use-package smartparens
  :ensure t
  :config
  (progn
    (smartparens-global-mode +1)
    (show-smartparens-global-mode +1)

    (defun sp-insert-or-up (delim &optional arg)
      "Insert a delimiter DELIM if inside a string, else move up."
      (interactive "sDelimiter:\nP")
      (if (or (emr-looking-at-string?)
              (emr-looking-at-comment?))
          (insert delim)
        (sp-up-sexp arg)))

    ;; Close paren keys move up sexp.
    (setq sp-navigate-close-if-unbalanced t)
    (--each '(")" "]" "}")
      (global-set-key (kbd it) (command (sp-insert-or-up it _arg))))

    (loop for (k f) in
          `(
            ("C-<backspace>" sp-backward-up-sexp)

            ("DEL"
             ;; delete unbalanced parens.
             ,(command (sp-backward-delete-char (or _arg 1))))

            ("C-k"
             ;; kill blank lines or balanced sexps.
             ,(command (if (emr-blank-line?)
                           (kill-whole-line)
                         (sp-kill-sexp))))

            ;; Still use Paredit wrap commands.
            ("M-{"  paredit-wrap-curly)
            ("M-["  paredit-wrap-square)
            ("M-("  paredit-wrap-round)

            ;; General prefix commands.

            ("C-x p a"      sp-absorb-sexp)
            ("C-x p b b"    sp-backward-barf-sexp)
            ("C-x p b f"    sp-forward-barf-sexp)
            ("C-x p c"      sp-convolute-sexp)
            ("C-x p e"      sp-emit-sexp)
            ("C-x p j"      sp-join-sexp)
            ("C-x p r"      sp-raise-sexp)
            ("C-x p s b"    sp-backward-slurp-sexp)
            ("C-x p s f"    sp-forward-slurp-sexp)
            ("C-x p s k a"  sp-splice-sexp-killing-around)
            ("C-x p s k b"  sp-splice-sexp-killing-backward)
            ("C-x p s k f"  sp-splice-sexp-killing-forward)
            ("C-x p s s"    sp-splice-sexp)
            ("C-x p t"      sp-transpose-sexp)
            ("C-x p u b"    sp-backward-unwrap-sexp)
            ("C-x p u f"    sp-unwrap-sexp)
            ("C-x p x"      sp-split-sexp)
            ("C-x p y"      sp-copy-sexp)
            )
          do (define-key sp-keymap (kbd k) f))))

(provide 'cb-smartparens)

;; Local Variables:
;; lexical-binding: t
;; End:

;;; cb-smartparens.el ends here
