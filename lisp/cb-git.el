;;; cb-git.el --- Configuration for git-related stuff

;; Copyright (C) 2013 Chris Barrett

;; Author: Chris Barrett <chris.d.barrett@me.com>
;; Version: 20130527.0012

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

;; Configuration for git-related stuff

;;; Code:

(require 'use-package)
(require 'cb-lib)

(define-prefix-command 'git-map)
(bind-key "C-x g" 'git-map)

(use-package magit
  :ensure t
  :defer  t
  :idle   (require 'magit)
  :commands magit-status
  :bind
  (("C-x g t" . magit-stash)
   ("C-x g c" . magit-checkout)
   ("C-x g u" . magit-pull)
   ("C-x g r" . magit-reflog)
   ("C-x g l" . magit-log)
   ("C-x g s" . magit-show)
   ("C-x g x" . magit-reset-head)
   ("C-x g X" . magit-reset-head-hard)
   ("C-x g d" . magit-diff-working-tree)
   ("C-x g D" . magit-diff))
  :init
  (progn

    (declare-modal-executor magit-status
      :command magit-status
      :bind    "M-G")

    (after 'dired
      (define-key dired-mode-map (kbd "M-G") 'magit-status))

    (evil-global-set-keys 'normal
      "g P" 'magit-key-mode-popup-pushing
      "g l" 'magit-log
      "g r" 'magit-reflog
      "g D" 'magit-diff-working-tree))

  :config
  (progn

    ;;;; Evil keys for magit diff.

    (define-key magit-diff-mode-map (kbd "C-f") 'evil-scroll-page-down)
    (define-key magit-diff-mode-map (kbd "C-b") 'evil-scroll-page-up)
    (define-key magit-diff-mode-map (kbd "j") 'evil-next-line)
    (define-key magit-diff-mode-map (kbd "k") 'evil-previous-line)
    (define-key magit-diff-mode-map (kbd "/") 'evil-search-forward)

    ;;;; View behaviour

    (declare-ido-wrapper magit-read-top-dir)
    (declare-modal-view magit-status)
    (declare-modal-view magit-log)
    (declare-modal-view magit-reflog)
    (declare-modal-view magit-diff-working-tree)
    (declare-modal-view magit-diff)

    (defadvice magit-show (after delete-window-on-kill activate)
      "When the buffer is killed, delete its corresponding window."
      (add-hook 'kill-buffer-hook 'delete-window nil t))

    (define-combined-hook cb:magit-command-hook
      ;; Search through interned symbols for magit hooks.
      (let (hooks)
        (mapatoms (lambda (sym)
                    (let ((str (symbol-name sym)))
                      (when (and (s-starts-with? "magit-" str)
                                 (s-ends-with? "-command-hook" str))
                        (setq hooks (cons sym hooks))))))
        hooks))

    (hook-fn 'cb:magit-command-hook
      "Update modelines to ensure vc status is up-to-date."
      (force-mode-line-update t))

    (add-hook 'magit-log-edit-mode-hook 'cb:append-buffer)
    (add-hook 'magit-mode-hook 'magit-load-config-extensions)))

(use-package magit-blame
  :commands magit-blame-mode
  :bind ("C-x g b" . magit-blame-mode))

(use-package git-auto-commit-mode
  :ensure t
  :commands git-auto-commit-mode
  :init
  (add-to-list 'safe-local-variable-values '(gac-automatically-push-p . t)))

(use-package git-gutter+
  :diminish git-gutter+-mode
  :ensure t
  :config
  (progn
    (--each '(find-file-hook after-save-hook)
      (hook-fn it
        "Enable git gutter when viewing files in a git repository."
        (when (vc-git-root (buffer-file-name))
          (require 'magit)
          (git-gutter+-mode +1))))

    (evil-global-set-keys 'normal
      "g n" 'git-gutter+-next-hunk
      "g p" 'git-gutter+-previous-hunk
      "g h" 'git-gutter+-popup-hunk
      "g x" 'git-gutter+-revert-hunk
      "g s" 'git-gutter+-stage-hunks
      "g c" 'git-gutter+-commit
      "g C" 'git-gutter+-stage-and-commit)

    (defadvice git-gutter+-commit (after select-log activate)
      "Select the log window when committing.
Ensure a window is created for the commit window."
      (let* ((buf (--first-buffer (derived-mode-p 'magit-log-edit-mode)))
             (win (--first-window (equal buf (window-buffer it)))))
        (if win
            (select-window win)
          (select-window (split-window-below -5))
          (switch-to-buffer buf))))))

(use-package git-gutter-fringe+
  :ensure t
  :if (or (daemonp) (display-graphic-p)))

(use-package gist
  :ensure t
  :commands
  (gist-list
   gist-region
   gist-region-private
   gist-buffergist-buffer-private
   gist-region-or-buffer
   gist-region-or-buffer-private))

(use-package gitconfig-mode
  :ensure t
  :defer  t
  :init
  (--each '(("/\\.gitconfig\\'"  . gitconfig-mode)
            ("/\\.git/config\\'" . gitconfig-mode))
    (add-to-list 'auto-mode-alist it)))

(use-package ediff
  :commands
  (ediff
   ediff-merge-files-with-ancestor)
  :init
  (progn

    (defun cb:apply-diff ()
      (let ((file ediff-merge-store-file))
        (set-buffer ediff-buffer-C)
        (write-region (point-min) (point-max) file)
        (message "Merge buffer saved in: %s" file)
        (set-buffer-modified-p nil)
        (sit-for 1)))

    (defun cb:handle-git-merge (local remote base merged)
      "Configure this emacs session for use as the git mergetool."
      (add-hook 'ediff-quit-hook 'kill-emacs)
      (add-hook 'ediff-quit-merge-hook 'cb:apply-diff)
      (ediff-merge-files-with-ancestor local remote base nil merged)))

  :config
  (progn
    (setq diff-switches "-u"
          ediff-window-setup-function 'ediff-setup-windows-plain)
    (add-hook 'ediff-startup-hook 'turn-off-evil-mode)))


(provide 'cb-git)

;; Local Variables:
;; lexical-binding: t
;; End:

;;; cb-git.el ends here
