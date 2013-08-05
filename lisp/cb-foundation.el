;;; cb-foundation.el --- Base configuration

;; Copyright (C) 2013 Chris Barrett

;; Author: Chris Barrett <chris.d.barrett@me.com>
;; Version: 20130527.0033

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

;; Base configuration

;;; Code:

(require 'use-package)
(require 'cb-lib)
(require 'noflet)

(defvar user-home-directory (concat (getenv "HOME") "/"))
(defvar user-dropbox-directory (concat user-home-directory "Dropbox/"))

(define-path cb:lib-dir       "lib/" t)
(define-path cb:lisp-dir      "lisp/" t)
(define-path cb:src-dir       "src")
(define-path cb:tmp-dir       "tmp/")
(define-path cb:elpa-dir      "elpa/")
(define-path cb:bin-dir       "bin/")
(define-path cb:etc-dir       "etc/")
(define-path cb:yasnippet-dir "snippets/")
(define-path cb:backups-dir   "backups/")
(define-path cb:autosaves-dir "tmp/autosaves/")

(defalias 'yes-or-no-p 'y-or-n-p)
(autoload 'edebug-step-mode "edebug")
(autoload 'server-running-p "server")
(autoload 'thing-at-point-looking-at "thingatpt")

(hook-fn 'after-init-hook
  (unless (server-running-p)
    (server-start)))

(use-package simple
  :diminish
  (visual-line-mode
   global-visual-line-mode
   auto-fill-mode))

;; Use the version of emacs in /src for info and source.
(setq source-directory (format "%s/emacs-%s.%s" cb:src-dir
                               emacs-major-version
                               emacs-minor-version))
(setenv "INFOPATH" (concat source-directory "/info/"))


(setq
 redisplay-dont-pause         t
 echo-keystrokes              0.02
 inhibit-startup-message      t
 transient-mark-mode          t
 shift-select-mode            nil
 require-final-newline        t
 delete-by-moving-to-trash    nil
 initial-major-mode           'fundamental-mode
 initial-scratch-message      nil
 x-select-enable-clipboard    t
 font-lock-maximum-decoration t
 ring-bell-function           'ignore
 initial-scratch-message      nil
 truncate-partial-width-windows     nil
 confirm-nonexistent-file-or-buffer nil
 vc-handled-backends          '(Git)
 system-uses-terminfo         nil
 bookmark-default-file        (concat cb:tmp-dir "bookmarks")
 )
(setq-default
 tab-width                    4
 indent-tabs-mode             nil
 fill-column                  80)

(add-hook 'text-mode-hook 'visual-line-mode)
(icomplete-mode +1)
(global-set-key (kbd "RET") 'comment-indent-new-line)

;; Enable alt latin input method
;; (setq-default default-input-method 'latin-alt-postfix)
(setq default-input-method 'latin-alt-postfix)
(hook-fn 'prog-mode-hook
  (set-input-method nil))

;; Encodings

(setq locale-coding-system   'utf-8)
(set-terminal-coding-system  'utf-8)
(set-keyboard-coding-system  'utf-8)
(set-selection-coding-system 'utf-8)
(prefer-coding-system        'utf-8)

;; File-handling

(auto-compression-mode +1)
(add-hook 'before-save-hook 'whitespace-cleanup)
(add-hook 'before-save-hook 'delete-trailing-whitespace)
(add-hook 'after-save-hook 'executable-make-buffer-file-executable-if-script-p)

(put 'activate-input-method 'safe-local-eval-function t)
(put 'set-input-method 'safe-local-eval-function t)

;;; Exiting Emacs

;; Rebind to C-c k k ("kill") to prevent accidentally exiting when
;; using Org bindings.
(bind-keys
  :overriding? t
  "C-x C-c" (command (message "Type <C-c k k> to exit Emacs"))
  "C-c k k" 'cb:exit-emacs-dwim
  "C-c k e" 'cb:exit-emacs)

(defun cb:exit-emacs ()
  (interactive)
  (when (yes-or-no-p "Kill Emacs? ")
    (save-buffers-kill-emacs)))

(defun cb:exit-emacs-dwim ()
  (interactive)
  (when (yes-or-no-p "Kill Emacs? ")
    (if (daemonp)
        (server-save-buffers-kill-terminal nil)
      (save-buffers-kill-emacs))))

;;; Help commands

(define-prefix-command 'help-find-map)
(bind-keys
  "C-h e"   'help-find-map
  "C-h e e" 'view-echo-area-messages
  "C-h e f" 'find-function
  "C-h e k" 'find-function-on-key
  "C-h e l" 'find-library
  "C-h e p" 'find-library
  "C-h e v" 'find-variable
  "C-h e a" 'apropos
  "C-h e V" 'apropos-value)

;;; Narrowing

(defun cb:narrow-dwim ()
  "Perform a context-sensitive narrowing command."
  (interactive)
  (cond ((buffer-narrowed-p)
         (widen)
         (recenter))

        ((region-active-p)
         (narrow-to-region (region-beginning)
                           (region-end)))
        (t
         (narrow-to-defun))))

(when (true? cb:use-vim-keybindings?)
  (bind-key "M-n" 'cb:narrow-dwim))
(put 'narrow-to-defun  'disabled nil)
(put 'narrow-to-page   'disabled nil)
(put 'narrow-to-region 'disabled nil)

(bind-key "C-c e e" 'toggle-debug-on-error)

;;; Editing Advice

(defun* sudo-edit (&optional (file (buffer-file-name)))
  "Edit FILE with sudo if permissions require it."
  (interactive)
  (when file
    (cond
     ((f-dir? file)
      (error "%s is a directory" file))

     ((file-writable-p file)
      (error "%s: sudo editing not needed" file))

     ;; Prompt user whether to escalate. Ensure the tramp connection is
     ;; cleaned up afterwards.
     ((and (yes-or-no-p "Edit file with sudo?  ")
           (find-alternate-file (concat "/sudo:root@localhost:" file)))
      (add-hook 'kill-buffer-hook 'tramp-cleanup-this-connection nil t)))))

(bind-key* "C-x e" 'sudo-edit)

(hook-fn 'find-file-hook
  "Offer to create a file with sudo if necessary."
  (let ((dir (file-name-directory (buffer-file-name))))
    (when (or (and (not (file-writable-p (buffer-file-name)))
                   (file-exists-p (buffer-file-name)))

              (and dir
                   (file-exists-p dir)
                   (not (file-writable-p dir))))
      (sudo-edit))))

(defadvice save-buffers-kill-emacs (around no-query-kill-emacs activate)
  "Suppress \"Active processes exist\" query when exiting Emacs."
  (noflet ((process-list () nil))
    ad-do-it))

(hook-fn 'kill-emacs-hook
  "Ensure tramp resources are released on exit."
  (ignore-errors
    (when (fboundp 'tramp-cleanup-all-buffers)
      (tramp-cleanup-all-buffers))))

(defadvice whitespace-cleanup (around whitespace-cleanup-indent-tab activate)
  "Fix `whitespace-cleanup' bug when using `indent-tabs-mode'."
  (let ((whitespace-indent-tabs-mode indent-tabs-mode)
        (whitespace-tab-width tab-width))
    ad-do-it))

(defadvice comment-indent-new-line (after add-space activate)
  "Add a space after opening a new comment line."
  (when (and comment-start
             (thing-at-point-looking-at (regexp-quote comment-start)))
    (unless (or (thing-at-point-looking-at (rx (+ space))))
      (just-one-space))))

(defadvice insert-for-yank (after clean-whitespace)
  "Remove trailing whitespace after insertion."
  (whitespace-cleanup)
  (delete-trailing-whitespace))

;;; Basic hooks

(defun cb:next-dwim ()
  "Perform a context-sensitive 'next' action."
  (interactive)
  (cond
   ((true? edebug-active)
    (edebug-step-mode))
   (t
    (next-error))))

(hook-fn 'prog-mode-hook
  "Generic programming mode configuration."

  ;; Error navigation keybindings.
  (local-set-key (kbd "M-N") 'cb:next-dwim)
  (local-set-key (kbd "M-P") 'previous-error)

  ;; Highlight special comments.
  (font-lock-add-keywords
   major-mode '(("\\<\\(FIX\\|TODO\\|FIXME\\|HACK\\|REFACTOR\\):"
                 1 font-lock-warning-face t))))

(hook-fn 'Buffer-menu-mode-hook
  "Buffer menu only shows files on disk."
  (Buffer-menu-toggle-files-only +1))

(hook-fn 'text-mode-hook
  (unless (derived-mode-p 'sgml-mode 'nxhtml-mode)
    (turn-on-auto-fill)))

(hook-fn 'after-init-hook
  "Ensure the user-home-directory is used as the default path,
rather than the app bundle."
  (setq default-directory user-home-directory)

  (load (concat user-emacs-directory "site-file.el") t t))

;;; View behaviour

(declare-modal-view package-list-packages)

;; Disable backups for files edited with tramp.
(after 'backup-dir
  (add-to-list 'bkup-backup-directory-info
               (list tramp-file-name-regexp ""))
  (setq tramp-bkup-backup-directory-info nil))

;;; Comint

;; Make comint read-only. This will stop the prompts from being editable
;; in inferior language modes.
(setq comint-prompt-read-only t)

(defun cb:append-buffer ()
  "Enter insertion mode at the end of the current buffer."
  (interactive)
  (goto-char (point-max))
  (if (fboundp 'evil-append-line)
      (evil-append-line 1)
    (end-of-line)))

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

(defadvice jit-lock-force-redisplay (around ignore-killed-buffers activate)
  "Do not perform font-locking on killed buffers."
  (let ((buf (ad-get-arg 0)))
    (when (buffer-live-p buf)
      ad-do-it)))

;;; Arrow keys are for suckers.

(defun you-lack-discipline ()
  "Admonish the user for using the arrow keys."
  (interactive)
  (let ((img (f-join cb:tmp-dir "discipline.jpg")))
    (unless (f-exists? img)
      (url-copy-file
       "http://ulrichdesign.ca/wp-content/uploads/2011/11/YOU-LACK-discipline.jpg"
       img))
    (insert-image (create-image img))
    (user-error "Arrow keys are not the Emacs Way")))

(--each '([up] [left] [down] [right])
  (define-key prog-mode-map it 'you-lack-discipline)
  (define-key text-mode-map it 'you-lack-discipline))

(provide 'cb-foundation)

;; Local Variables:
;; lexical-binding: t
;; End:

;;; cb-foundation.el ends here
