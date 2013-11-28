;;; cb-idris.el --- Configuration for the Idris language.

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

;; Configuration for the Idris language.

;;; Code:

(require 'use-package)
(require 'cb-lib)
(require 'cb-mode-groups)
(autoload 'idris-indentation-indent-line "idris-indentation")
(autoload 'idris-newline-and-indent "idris-indentation")
(autoload 'sp-end-of-sexp "smartparens")
(autoload 'sp-get-sexp "smartparens")
(autoload 'thing-at-point "thingatpt")
(autoload 'thing-at-point-looking-at "thingatpt")
(autoload 'smart-insert-operator "smart-operator")

;; Configure smart operators for Idris
;;
;; These are more or less duplicates of the Haskell functions.

(defun cbidris:smart-comma ()
  (interactive)
  (cond
   ((s-matches? (rx bol (* space) eol)
                (buffer-substring (line-beginning-position) (point)))
    (insert ", ")
    (idris-indentation-indent-line))
   (t
    (insert ","))))

(defun cbidris:smart-pipe ()
  "Insert a pipe operator. Add padding, unless we're inside a list."
  (interactive)
  (if (s-matches? (rx "[" (* (any "|" alnum)) eol)
                  (buffer-substring (line-beginning-position) (point)))
      (insert "|")
    (smart-insert-operator "|")))

(defun cbidris:looking-at-module-or-constructor? ()
  (-when-let (sym (thing-at-point 'symbol))
    (s-uppercase? (substring sym 0 1))))

(defun cbidris:smart-dot (&optional arg)
  "Insert a period. Add padding, unless this line is an import statement.
With a prefix arg, insert a period without padding."
  (interactive "*P")
  (cond
   (arg
    (insert "."))
   ((cbidris:looking-at-module-or-constructor?)
    (insert "."))
   ((thing-at-point-looking-at (rx (or "(" "{" "[") (* space)))
    (insert "."))
   (t
    (smart-insert-operator "."))))

(defun cbidris:smart-colon ()
  (interactive)
  (if (s-matches? (rx "(" (* (not alnum)) eol)
                  (buffer-substring (line-beginning-position) (point)))
      (insert ":")
    (smart-insert-operator ":"))
  (idris-indent-dwim t))

(defun cbidris:insert-arrow (arrow)
  "If point is inside a tuple, insert an arrow inside.
Otherwise insert an arrow at the end of the line."
  (atomic-change-group
    (cl-destructuring-bind (&key beg end op &allow-other-keys)
        (sp-get-sexp t)
      ;; Check whether point is inside a tuple.
      (if (and (equal op "(")
               (> (point) beg)
               (< (point) end))
          (sp-end-of-sexp)
        (end-of-line)))
    ;; Insert arrow.
    (just-one-space)
    (insert arrow)
    (just-one-space)))

(defun cbidris:at-typedecl? ()
  (s-matches? (rx space ":" (not (any ":")))
              (buffer-substring (line-beginning-position) (point))))

(defun cbidris:smart-minus (&optional arg)
  "Insert an arrow if we're in a typesig, otherwise perform a normal insertion.
With a prefix arg, insert an arrow with padding at point."
  (interactive "*P")
  (cond
   (arg
    (just-one-space)
    (insert "->")
    (just-one-space))
   ((cbidris:at-typedecl?)
    (cbidris:insert-arrow "->"))
   (t
    (smart-insert-operator "-"))))

(defun cbidris:smart-lt (&optional arg)
  "Insert a less than symbol. With a prefix arg, insert an arrow at point."
  (interactive "*P")
  (cond
   (arg
    (just-one-space)
    (insert "<-")
    (just-one-space))
   (t
    (smart-insert-operator "<"))))

(add-hook 'cb:idris-modes-hook 'smart-insert-operator-hook)

(bind-keys
  :hook cb:idris-modes-hook
  "," 'cbidris:smart-comma
  "-" 'cbidris:smart-minus
  "=" (command (smart-insert-operator "="))
  "<" 'cbidris:smart-lt
  "." 'cbidris:smart-dot
  ":" 'cbidris:smart-colon
  "|" 'cbidris:smart-pipe
  "?" (command (smart-insert-operator "?"))
  "$" (command (smart-insert-operator "$")))

;; Define code formatting commands for idris-mode.

(defun cbidris:data-start-pos ()
  "Find the start position of the datatype declaration at point."
  (save-excursion
    (end-of-line)
    (search-backward-regexp (rx bol "data" eow) nil t)))

(defun cbidris:data-end-pos ()
  "Find the end position of the datatype declaration at point."
  (save-excursion

    (when (s-matches? (rx bol "data" eow) (current-line))
      (goto-char (line-end-position)))

    (-when-let* ((start (point))
                 (end (cond
                       ((eobp) (point))
                       ((s-blank? (current-line)) nil)
                       ((search-forward-regexp
                         (rx bol (or (and (* space) eol)
                                     (not space))) nil t)
                        (1- (line-beginning-position))))))
      (when (<= start end)
        end))))

(cl-defun cbidris:data-decl-at-pt ()
  "Return the data declaration at point."
  (-when-let* ((start (cbidris:data-start-pos))
               (end (cbidris:data-end-pos)))
    (buffer-substring-no-properties start end)))

(defun cbidris:at-data-decl? ()
  (-when-let (dd (cbidris:data-decl-at-pt))
    (let ((lines (s-split "\n" dd)))
      (or (equal 1 (length lines))
          (->> (-drop 1 lines)
            (-all? (~ s-matches? (rx bol space))))))))

(cl-defun cbidris:goto-type-judgement-colon
    (&optional (bound (cbidris:data-end-pos)))
  (ignore-errors
    (goto-char (line-beginning-position))
    (search-forward " : " bound)
    (search-backward ":")))

(defun cbidris:max-colon-column-in-data ()
  "Find the greatest column of type judgements in a data decl."
  (->> (save-excursion
         (cl-loop
          while (and (not (eobp))
                     (cbidris:at-data-decl?))
          collect (progn
                    (cbidris:goto-type-judgement-colon)
                    (current-column))
          do (progn
               (forward-line)
               (end-of-line))))
    (-remove 'null)
    (cons 0)
    (-max)))

(defun cbidris:indent-data-decl ()
  "Indent the data decl at point."
  (interactive)
  (when (< 1 (->> (cbidris:data-decl-at-pt)
               (s-split "\n")
               (length)))
    (save-excursion

      (goto-char (cbidris:data-start-pos))

      (when (s-starts-with? "data" (current-line))
        (forward-line 1))

      (let (done)
        (while (and (not done) (cbidris:at-data-decl?))
          (goto-char (line-beginning-position))
          (delete-horizontal-space)
          (indent-for-tab-command)
          (if (eobp)
              (setq done t)
            (forward-line)))))))

(defun cbidris:normalise-data-decl-colons ()
  (save-excursion
    (let ((start (cbidris:data-start-pos)))

      (goto-char start)
      (while (search-forward-regexp
              (rx space ":" (or space eol))
              (cbidris:data-end-pos) t)
        (save-excursion
          (search-backward ":")
          (just-one-space)))

      (goto-char start)
      (let ((col (cbidris:max-colon-column-in-data))
            done)
        (while (and (not done)
                    (cbidris:at-data-decl?))
          (when (cbidris:goto-type-judgement-colon)
            (indent-to col))
          (goto-char (line-end-position))
          (if (eobp)
              (setq done t)
            (forward-line)))))))

(defun cbidris:format-data-decl ()
  "Align colons in a datatype declaration."
  (interactive)
  (when (cbidris:at-data-decl?)
    (cbidris:indent-data-decl)
    (cbidris:normalise-data-decl-colons)
    t))

(defun idris-indent-dwim (&optional silent?)
  "Perform a context-sensitive indentation command.
SILENT? controls whether provide feedback to the user on the action performed."
  (interactive "*")
  (save-excursion
    (cond
     ((cbidris:format-data-decl)
      (unless silent?
        (message "Indented data declaration.")))
     (t
      (unless silent?
        (user-error "Unable to indent"))))))

(defun idris-ret ()
  "Indent and align on newline."
  (interactive "*")
  (if (s-matches? comment-start (current-line))
      (comment-indent-new-line)
    (idris-indent-dwim t)
    (idris-newline-and-indent)))

(after 'idris-mode
  (define-keys idris-mode-map
    "M-q" 'idris-indent-dwim
    "<return>" 'idris-ret))

;; Configure Smartparens.
(after 'smartparens
  (sp-with-modes cb:idris-modes
    (sp-local-pair "'" "'" :actions '(:rem insert))))

;; Use font lock to display Unicode symbols in Idris buffers.
(after 'idris-mode

  (defun cbidris:apply-font-lock (pat rep)
    "Call SUBSTITUTE-PATTERN-WITH-UNICODE repeatedly."
    (font-lock-add-keywords
     nil `((,pat
            (0 (progn (compose-region (match-beginning 1) (match-end 1)
                                      ,(string-to-char rep) 'decompose-region)
                      nil))))))

  (defun cbidris:font-lock (patterns)
    (--each patterns
      (cl-destructuring-bind (pat rep) it
        (cbidris:apply-font-lock
         (rx-to-string `(and (not (any "\""))
                             (? "`")
                             (group  symbol-start ,pat symbol-end)
                             (? "`")
                             (not (any "\""))))
         rep))))

  (defun cbidris:apply-unicode ()
    (cbidris:apply-font-lock
     "\\s ?(?\\(\\\\\\)\\s *\\(\\w\\|_\\|(.*)\\).*?\\s *->" "λ")
    (cbidris:font-lock '(("<-"     "←")
                         ("->"     "→")
                         ("=>"     "⇒")
                         ("."      "•")
                         ("forall" "∀")
                         ("undefined" "⊥")
                         (">="     "≥")
                         ("<="     "≤")
                         ("=="     "≣")
                         ("alpha"  "ɑ")
                         ("beta"   "β")
                         ("gamma"  "ɣ")
                         ("delta"  "δ")
                         ("elem"   "∈")
                         ("notElem" "∉")
                         ("!!"     "‼"))))

  (add-hook 'cb:idris-modes-hook 'cbidris:apply-unicode))

;; `idris-mode' provides editing support for the Idris language.
(use-package idris-mode
  :mode (("\\.idr$" . idris-mode))
  :config
  (after 'idris-mode
    (define-key idris-mode-map (kbd "C-c C-z") 'idris-switch-to-output-buffer)))

;; Define a command to switch from the repl to the last Idris src buffer.

(defun idris-switch-to-src ()
  "Pop to the last idris source buffer."
  (interactive)
  (-if-let (buf (car (--filter-buffers (derived-mode-p 'idris-mode))))
      (pop-to-buffer buf)
    (error "No idris buffers")))

(after 'idris-repl
  (define-key idris-repl-mode-map (kbd "C-c C-z") 'idris-switch-to-src))

(provide 'cb-idris)

;;; cb-idris.el ends here
