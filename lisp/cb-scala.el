;;; cb-scala.el --- Configuration for Scala.

;; Copyright (C) 2013 Chris Barrett

;; Author: Chris Barrett <chris.d.barrett@me.com>
;; Version: 0.1

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

;; Configuration for Scala.

;;; Code:

(require 'cb-lib)
(require 'use-package)

;; `scala-mode2' provides support for the Scala language.
(use-package scala-mode2
  :ensure t
  :commands scala-mode
  :config
  (setq scala-indent:align-forms t
        scala-indent:align-parameters t
        scala-indent:default-run-on-strategy scala-indent:eager-strategy))

;; `ensime' adds IDE-like features to scala-mode.
(use-package ensime
  :ensure t
  :commands ensime-mode
  :init
  (hook-fn 'scala-mode-hook (ensime-mode +1)))

;; Configure `evil-mode' commands for Scala.
(after '(evil scala-mode2)

  (defun cbscala:join-line ()
    "Adapt `scala-indent:join-line' to behave more like evil's line join."
    (interactive)
    (let (join-pos)
      (save-excursion
        (goto-char (line-end-position))
        (unless (eobp)
          (forward-line)
          (call-interactively 'scala-indent:join-line)
          (setq join-pos (point))))
      (goto-char join-pos)))

  (evil-define-key 'normal scala-mode-map
    "J" 'cbscala:join-line))

;; Add ac sources for Scala keywords.
(after 'auto-complete

  (defconst cbscala:scala-keywords
    '("abstract" "case" "catch" "class" "def" "do" "else" "extends" "false" "final"
      "finally" "for" "forSome" "if" "implicit" "import" "lazy" "match" "new" "null"
      "object" "override" "package" "private" "protected" "return" "sealed" "super"
      "this" "throw" "trait" "try" "true" "type" "val" "var" "while" "with" "yield"
      "-" ":" "=" "=>" "<-" "<:" "<%" ">:" "#" "@")
    "List of keywords reserved by the scala language.")

  (ac-define-source scala-keywords
    '((symbol . "k")
      (candidates . cbscala:scala-keywords)
      (action . just-one-space)))

  (add-to-list 'ac-modes 'scala-mode)
  (hook-fn 'ensime-mode-hook
    (setq ac-auto-start 2)
    (-each '(ac-source-yasnippet
             ac-source-scala-keywords
             ac-source-ensime-completions)
           (~ add-to-list 'ac-sources))))

;; Auxiliary functions for Scala snippets.
(after 'yasnippet

  (defun cbscala:find-case-class-parent ()
    (save-excursion
      (if (search-backward-regexp
           (rx (or
                (and bol (* space)
                     "abstract" (+ space) "class" (+ space) (group-n 1 (+ alnum)))
                (and bol (* space)
                     "case" (+ space) "class" (* anything) space
                     "extends" (+ space) (group-n 1 (+ alnum)) (* space) eol)))
           nil t)
          (match-string 1)
        ""))))

(provide 'cb-scala)

;; Local Variables:
;; lexical-binding: t
;; End:

;;; cb-scala.el ends here
