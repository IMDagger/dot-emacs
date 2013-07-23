;;; cb-python.el --- Configuration for python

;; Copyright (C) 2013 Chris Barrett

;; Author: Chris Barrett <chris.d.barrett@me.com>
;; Version: 20130526.2358

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

;; Configuration for python

;;; Code:

(require 'use-package)
(require 'cb-foundation)
(autoload 'emr-line-matches? "emr")

(after 'auto-complete
  (add-to-list 'ac-modes 'python-mode)
  (add-to-list 'ac-modes 'inferior-python-mode))

(after 'smart-operator

  (defun cb:python-equals ()
    "Insert an '=' char padded by spaces, except in function arglists."
    (interactive)
    (if (emr-line-matches? (rx (* space) "def" (+ space)))
        (insert "=")
      (smart-insert-operator "=")))

  (hook-fn 'cb:python-modes-hook
    (smart-insert-operator-hook)
    (local-set-key (kbd "=") 'cb:python-equals)
    (local-unset-key (kbd "."))
    (local-unset-key (kbd ":"))))

(after 'smartparens
  (sp-with-modes cb:python-modes
    (sp-local-pair "{" "}" :post-handlers '(:add sp-generic-leading-space))))

(use-package python
  :ensure   t
  :commands python-mode
  :mode     ("\\.py$" . python-mode)
  :init
  (hook-fn 'python-mode-hook
    ;; Python-mode is not derived from prog mode, but we still want all the
    ;; programming goodies.
    (run-hooks 'prog-mode-hook))

  :config
  (progn
    ;; Use ipython if installed.
    (-when-let (ipython (executable-find "ipython"))
      (setq
       python-shell-interpreter ipython
       python-shell-interpreter-args ""
       python-shell-prompt-regexp "In \\[[0-9]+\\]: "
       python-shell-prompt-output-regexp "Out\\[[0-9]+\\]: "
       python-shell-completion-setup-code
       "from IPython.core.completerlib import module_completion"
       python-shell-completion-module-string-code
       "';'.join(module_completion('''%s'''))\n"
       python-shell-completion-string-code
       "';'.join(get_ipython().Completer.all_completions('''%s'''))\n"))

    (defun cb-py:restart-python ()
      (save-window-excursion
        (let (kill-buffer-query-functions
              (buf (get-buffer "*Python*")))
          (when buf (kill-buffer buf)))
        (call-interactively 'run-python)))

    (defun cb:switch-to-python ()
      "Switch to the last active Python buffer."
      (interactive)
      ;; Start inferior python if necessary.
      (unless (->> (--first-buffer (derived-mode-p 'inferior-python-mode))
                (get-buffer-process)
                (processp))
        (cb-py:restart-python))

      (if (derived-mode-p 'inferior-python-mode)
          ;; Switch from inferior python to source file.
          (switch-to-buffer-other-window
           (--first-buffer (derived-mode-p 'python-mode)))
        ;; Switch from source file to REPL.
        ;; HACK: `switch-to-buffer-other-window' does not change window
        ;; when switching to REPL buffer. Work around this.
        (-when-let* ((buf (--first-buffer (derived-mode-p 'inferior-python-mode)))
                     (win (or (--first-window (equal (get-buffer "*Python*")
                                                     (window-buffer it)))
                              (split-window-sensibly)
                              (next-window))))
          (set-window-buffer win buf)
          (select-window win)
          (goto-char (point-max))
          (when (fboundp 'evil-append-line)
            (evil-append-line 1)))))

    (defun cb-py:eval-dwim (&optional arg)
      (interactive "P")
      (cond
       ((region-active-p)
        (python-shell-send-region (region-beginning) (region-end))
        (deactivate-mark))
       (t
        (python-shell-send-defun arg))))

    (define-keys python-mode-map
      "," 'cb:comma-then-space
      "C-c C-z" 'cb:switch-to-python
      "C-c C-c" 'cb-py:eval-dwim)

    (define-keys inferior-python-mode-map
      "," 'cb:comma-then-space
      "C-c C-z" 'cb:switch-to-python)))

(use-package jedi
  :ensure   t
  :commands jedi:setup
  :init     (add-hook 'cb:python-modes-hook 'jedi:setup)
  :config   (setq jedi:setup-keys t))

(use-package virtualenv
  :ensure t
  :commands (virtualenv-workon
             virtualenv-deactivate
             virtualenv-minor-mode)
  :init
  (after 'python
    (add-hook 'find-file-hook 'virtualenv-minor-mode)))

(provide 'cb-python)

;; Local Variables:
;; lexical-binding: t
;; End:

;;; cb-python.el ends here
