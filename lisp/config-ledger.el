;;; config-ledger.el --- Configuration for Ledger.

;; Copyright (C) 2014 Chris Barrett

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

;; Configuration for Ledger.

;;; Code:

(require 'utils-common)
(require 'utils-ui)
(require 'config-theme)

(cb:install-package 'ledger-mode)
(add-to-list 'auto-mode-alist '("\\.ledger$" . ledger-mode))

(custom-set-variables
 '(ledger-post-account-alignment-column 2)
 '(ledger-post-use-completion-engine :ido))

(after 'config-orgmode
  (add-to-list 'org-action-picker-options
               '("$" "Go to ledger" (lambda () (find-file ledger-file)))))

(after 'org-capture

  (defmacro cbledger:with-ledger-buffer (&rest body)
    "Execute BODY forms in a ledger buffer.
Use `ledger-buffer' if the current buffer is not in ledger-mode."
    (declare (indent 0))
    `(with-current-buffer ,(if (derived-mode-p 'ledger-mode)
                               (current-buffer)
                             (find-file-noselect ledger-file))
       ,@body))

  (defun cbledger:read-date ()
    (s-replace "-" "/" (car (s-split " " (org-read-date)))))

  (defun cbledger:read-payee ()
    (cbledger:with-ledger-buffer
      (ido-completing-read "Payee: " (ledger-payees-in-buffer))))

  (defun cbledger:read-clear-state ()
    (if (y-or-n-p "Transaction cleared? ") " * " " "))

  (defun cbledger:read-amount ()
    (format "$ %.2f" (read-number "Amount $: ")))

  (defun cbledger:accounts ()
    "Find all accounts in the current ledger buffer, or in the `ledger-file'."
    (cbledger:with-ledger-buffer
      (->> (s-match-strings-all
            (rx bol (+ space) (group (+ (not space)) ":" (+? nonl))
                (or eol "  "))
            (buffer-string))
        (-map 'cadr)
        (-concat '("Income" "Assets" "Liabilities" "Expenses"))
        (-uniq)
        (-sort 'string<))))

  (cl-defun cbledger:read-account (&optional (prompt "Account: ") initial-input)
    (ido-completing-read prompt (cbledger:accounts) nil nil initial-input))

  (defun cbledger:read-expense ()
    (let ((date (cbledger:read-date))
          (payee (cbledger:read-payee))
          (to-account (cbledger:read-account "To: " "Expenses:"))
          (amount (cbledger:read-amount))
          (from-account (cbledger:read-account "From: " "Assets:Checking"))
          (cleared? (cbledger:read-clear-state)))
      (concat date cleared? payee "\n"
              "  " to-account "  " amount "\n"
              "  " from-account)))

  (add-to-list 'org-capture-templates
               `("$" "Expense" plain (file ,ledger-file)
                 (function cbledger:read-expense)
                 :empty-lines 1
                 :clock-keep t
                 :jump-to-captured t
                 :immediate-finish t)))

(after 'ledger-mode

  (defvar cbledger:transaction-start (rx bol (any digit "~" "="))
    "Regex matching the start of a transaction line.")

  (cl-defun ledger-transaction-at-pt (&optional (pt (point)))
    "Return the transaction at PT."
    (goto-char pt)
    (-when-let* ((beg (ledger-transaction-start-pos))
                 (end (ledger-transaction-end-pos)))
      (buffer-substring-no-properties beg end)))

  (cl-defun ledger-cur-transaction-date ()
    "Return the date for the transaction at point"
    (-when-let (trans (ledger-transaction-at-pt))
      (car (s-match ledger-full-date-regexp trans))))

  (defun ledger-transaction-start-pos ()
    "Return the buffer position where the transaction at point begins."
    (save-excursion
      (if (s-matches? cbledger:transaction-start (current-line))
          (goto-char (line-beginning-position))
        (ignore-errors
          (ledger-prev-transaction)))))

  (defun ledger-transaction-end-pos ()
    "Return the buffer position where the transaction at point ends."
    (save-excursion
      (or (ignore-errors (ledger-next-transaction))
          (goto-char (point-max)))

      (let (pos)
        (forward-line -1)
        (goto-char (line-end-position))
        (setq pos (point))
        (while (s-matches? (rx bol (* space) eol) (current-line))
          (forward-line -1)
          (goto-char (line-end-position))
          (setq pos (point)))
        pos)))

  (defun ledger-move-to-date (date)
    "Move to DATE in the ledger file."
    ;; Use slashes for consistency with ledger's date format.
    (interactive (list (s-replace "-" "/" (org-read-date))))
    (cl-destructuring-bind (y m d) (-map 'string-to-number (s-split "/" date))
      (ledger-xact-find-slot (encode-time 0 0 0 d m y))))

  (define-key ledger-mode-map (kbd "C-c C-d") 'ledger-move-to-date)

  (defun ledger-format-buffer ()
    "Reformat the buffer."
    (interactive "*")
    (let ((pt (point)))
      (save-excursion
        (ledger-post-align-postings (point-min) (point-max))
        (ledger-sort-buffer)
        (message "Formatted buffer"))
      (goto-char pt)))

  (hook-fn 'ledger-mode-hook
    (add-hook 'before-save-hook 'ledger-format-buffer nil t))

  (define-key ledger-mode-map (kbd "M-q") 'ledger-format-buffer)

  (defun ledger-ret ()
    "Newline and format."
    (interactive "*")
    (cond
     ((s-matches? (rx bol (* space) eol) (current-line))
      (delete-horizontal-space)
      (newline))
     (t
      (ledger-post-align-postings)
      (newline)
      (indent-to ledger-post-account-alignment-column))))

  (define-key ledger-mode-map (kbd "RET") 'ledger-ret)

  (defun ledger-prev-transaction (&optional count)
    "Move backward to the start of the last transaction."
    (interactive)
    (goto-char (line-beginning-position))
    (cond
     ((bobp)
      (user-error "Beginning of buffer"))
     ((search-backward-regexp cbledger:transaction-start nil t count)
      (goto-char (line-beginning-position)))
     (t
      (goto-char (point-min)))))

  (defun ledger-next-transaction (&optional count)
    "Move forward to the start of the next transaction."
    (interactive)
    (let ((start (point)))
      (goto-char (line-end-position))
      (if (search-forward-regexp cbledger:transaction-start nil t count)
          (goto-char (line-beginning-position))
        (goto-char start)
        (user-error "End of buffer"))))

  (define-key ledger-mode-map (kbd "M-P") 'ledger-prev-transaction)
  (define-key ledger-mode-map (kbd "M-N") 'ledger-next-transaction)

  (defun cbledger:delete-transaction-at-pt ()
    "Kill the current transaction.
Behaves correctly for transactions that are not separated by blank lines."
    (when (s-blank? (ledger-transaction-at-pt))
      (error "Not at a transaction"))
    (delete-region (ledger-transaction-start-pos)
                   (ledger-transaction-end-pos))
    (collapse-vertical-whitespace)
    (forward-line))

  (defun ledger-kill-transaction-at-pt ()
    "Kill the transaction at point and add it to the kill ring."
    (interactive "*")
    (-if-let (trans (ledger-transaction-at-pt))
        (progn
          (kill-new trans)
          (cbledger:delete-transaction-at-pt)
          (when (called-interactively-p nil)
            (message "Transaction copied to kill-ring"))
          trans)
      (user-error "Point is not at a transaction")))

  (define-key ledger-mode-map (kbd "C-c C-k") 'ledger-kill-transaction-at-pt)

  (defun ledger-periodic-transaction? (str)
    "Non-nil if STR is a periodic transaction."
    (when str (s-starts-with? "~" str)))

  (defun ledger-transpose-transactions ()
    "Swap the current transaction with the preceding one.
The transactions must have matching dates."
    (interactive "*")
    (let ((start (point)))
      (goto-char (ledger-transaction-start-pos))
      (let* ((trans (ledger-transaction-at-pt))
             (date (ledger-cur-transaction-date))
             (periodic? (ledger-periodic-transaction? trans)))
        (cond
         ((null trans)
          (goto-char start)
          (user-error "Point is not at a valid transaction"))

         ((and (null date) (not periodic?))
          (goto-char start)
          (error "Invalid date for current transaction"))

         ((save-excursion
            (ledger-prev-transaction)
            (equal periodic? (not (ledger-periodic-transaction?
                                   (ledger-transaction-at-pt)))))
          (goto-char start)
          (user-error "Incompatable transaction types"))

         ;; Inspect the preceding transaction to see whether we can transpose.
         ((save-excursion
            (ledger-prev-transaction)
            (equal date (ledger-cur-transaction-date)))

          (unwind-protect
              (atomic-change-group
                (ledger-kill-transaction-at-pt)
                (ledger-prev-transaction)
                (forward-line -1)
                (unless (bobp) (newline))
                (save-excursion
                  (insert trans)
                  (newline)
                  (collapse-vertical-whitespace)))

            (pop kill-ring)))

         (t
          (goto-char start)
          (user-error "Transaction dates do not match"))))))

  (defun ledger-move-transaction-up ()
    "Move the current transaction up.
Signal an error of doing so would break date ordering."
    (interactive "*")
    (ledger-transpose-transactions))

  (defun ledger-move-transaction-down ()
    "Move the current transaction down.
Signal an error of doing so would break date ordering."
    (interactive "*")
    (let ((pt (point)))
      (unwind-protect
          (progn
            (ledger-next-transaction)
            (ledger-transpose-transactions))
        (goto-char pt))
      (ledger-next-transaction)))

  (define-key ledger-mode-map (kbd "M-<up>") 'ledger-move-transaction-up)
  (define-key ledger-mode-map (kbd "M-<down>") 'ledger-move-transaction-down)

  (defun cbledger:insert-timestamp (date)
    "Insert a timestamp at point."
    (interactive (list (org-read-date)))
    (insert (s-replace "-" "/" date))
    (just-one-space)
    (when (true? evil-mode)
      (evil-insert-state)))

  (define-key ledger-mode-map (kbd "C-c C-.") 'cbledger:insert-timestamp)

  (define-key ledger-mode-map (kbd "C-c C-c") 'ledger-report)
  (define-key ledger-mode-map (kbd "M-RET") 'ledger-toggle-current-transaction)

  (add-hook 'ledger-report-mode-hook 'flyspell-mode-off)

  (--each
      '(("net worth" "ledger -f %(ledger-file) bal ^assets ^liabilities")
        ("cash flow" "ledger -f %(ledger-file) bal ^income ^expenses")
        ("checking" "ledger -f accounts.ledger --start-of-week friday -p 'this week' -r reg 'checking' --invert")
        )
    (add-to-list 'ledger-reports it t))

  (cl-delete-if (C (~ equal "payee") car) ledger-report-format-specifiers)
  (add-to-list 'ledger-report-format-specifiers '("payee" . cbledger:read-payee))

  (cl-delete-if (C (~ equal "account") car) ledger-report-format-specifiers)
  (add-to-list 'ledger-report-format-specifiers '("account" . cbledger:read-account))

  (defun ledger-report-payee-format-specifier ()
    (let ((payee (ledger-xact-payee)))
      (ledger-read-string-with-default
       "Payee" (when payee (regexp-quote payee)))))

  (set-face-background 'ledger-font-xact-highlight-face nil)
  (set-face-foreground 'ledger-font-comment-face
                       (face-foreground 'font-lock-comment-face))
  (set-face-foreground 'ledger-font-posting-account-face
                       (face-foreground 'default))

  (set-face-foreground 'ledger-font-pending-face solarized-hl-orange)
  (set-face-foreground 'ledger-font-payee-cleared-face solarized-hl-green)
  (set-face-foreground 'ledger-font-payee-uncleared-face solarized-hl-orange)

  (defface ledger-date
    `((t :inherit org-date :underline nil :foreground ,solarized-hl-cyan))
    "Face for dates at start of transactions."
    :group 'ledger-faces)

  (defface ledger-periodic-header
    `((t :foreground ,solarized-hl-violet :bold t))
    "Face for the header for periodic transactions."
    :group 'ledger-faces)

  (defface ledger-year-line
    `((t :foreground ,solarized-hl-violet))
    "Face for year declarations."
    :group 'ledger-faces)

  (font-lock-add-keywords
   'ledger-mode
   `((,(rx bol (+ (any digit "=" "/"))) . 'ledger-date)
     (,(rx bol "~" (* nonl)) . 'ledger-periodic-header)
     (,(rx bol "year" (+ space) (+ digit) (* space) eol) . 'ledger-year-line)))

  (after 'flycheck
    (cb:install-package 'flycheck-ledger t))

  (defvar ledger--transaction-start-re (rx bol (any digit "~" "="))
    "Regex matching the start of a transaction line.")

  (defun ledger--hs-forward (&optional n)
    "Forward motion command for ledger-mode's hideshow support.
Argument N is provided for compatibility and is not used."
    (forward-line 1)
    (or (when (search-forward-regexp ledger--transaction-start-re nil t)
          (forward-line -1)
          (goto-char (line-end-position))
          t)
        (goto-char (point-max))))

  (eval-after-load 'hideshow
    '(add-to-list 'hs-special-modes-alist
                  `(ledger-mode
                    ,ledger--transaction-start-re
                    nil
                    nil
                    ledger--hs-forward
                    nil)))

  (add-hook 'ledger-mode-hook 'hs-minor-mode)

  (evil-define-key 'normal ledger-report-mode-map
    "e" 'ledger-report-edit
    "q" 'ledger-report-kill
    "r" 'ledger-report-redo
    "R" 'ledger-report-reverse-lines
    "s" 'ledger-report-save)

  (add-hook 'ledger-transaction-inserted-hook 'evil-insert-state)

  )

(provide 'config-ledger)

;;; config-ledger.el ends here
