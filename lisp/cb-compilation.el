;;; cb-compilation.el --- Configuration for compilation and checking

;; Copyright (C) 2013 Chris Barrett

;; Author: Chris Barrett <chris.d.barrett@me.com>
;; Version: 20130527.0010

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

;; Configuration for compilation and checking

;;; Code:

(require 'use-package)

(use-package compile
  :bind
  (("C-c b" . compile)
   ("C-c C-b" . recompile))
  :config
  (progn

    (defun cb:compile-autoclose (buf string)
      "Automatically close the compile window."
      (cond
       ;; Ignore if this isn't a normal compilation window.
       ((not (equal (buffer-name buf) "*compilation*")))

       ((not (s-contains? "finished" string))
        (message "Compilation exited abnormally: %s" string))

       ((s-contains? "warning" (with-current-buffer buf
                                 (buffer-string)) 'ignore-case)
        (message "Compilation succeeded with warnings"))

       (t
        (ignore-errors
          (delete-window (get-buffer-window buf)))
        (message "Compilation succeeded"))))

    (hook-fn 'find-file-hook
      "Try to find a makefile for the current project."
      (when (projectile-project-p)
        (setq-local compilation-directory (projectile-project-root))))

    (defun cb:ansi-colourise-compilation ()
      (ansi-color-apply-on-region compilation-filter-start (point)))

    (setq
     compilation-window-height    12
     compilation-scroll-output    'first-error)
    (add-to-list 'compilation-finish-functions 'cb:compile-autoclose)
    (add-hook 'compilation-filter-hook 'cb:ansi-colourise-compilation)))

(use-package mode-compile
  :ensure t
  :bind
  (("C-c ."   . mode-compile-kill)
   ("C-c C-c" . mode-compile))
  :init
  (define-key prog-mode-map (kbd "C-c C-c") 'mode-compile)
  :config
  (progn
    (when (executable-find "clang")
      (setq
       cc-compilers-list (list "clang")
       cc-default-compiler "clang"
       cc-default-compiler-options "-fno-color-diagnostics -g"))

    (setq mode-compile-expert-p             t
          mode-compile-always-save-buffer-p t)))

(use-package flyspell
  :diminish flyspell-mode
  :defer    t
  :init
  (progn
    (setq ispell-dictionary "english")
    (add-hook 'text-mode-hook 'flyspell-mode)
    (hook-fn 'cb:xml-modes-hook
      (unless (derived-mode-p 'markdown-mode)
        (flyspell-prog-mode)))
    ;; TOO ANNOYING!
    ;; (add-hook 'prog-mode-hook 'flyspell-prog-mode)
    )
  :config
  (progn
   (bind-key* "C-'" 'flyspell-auto-correct-word)
   (define-key flyspell-mouse-map [down-mouse-3] 'flyspell-correct-word)
   (define-key flyspell-mouse-map [mouse-3] 'undefined)))

(use-package flyspell-lazy
  :ensure  t
  :defer   t
  :init (add-hook 'flyspell-mode-hook 'flyspell-lazy-mode))

(use-package flycheck
  :ensure t
  :commands
  (flycheck-mode
   flycheck-may-enable-mode)
  :init
  (--each '(prog-mode-hook text-mode-hook)
    (hook-fn it
      (when (flycheck-may-enable-mode)
        (flycheck-mode +1))))
  :config
  (defadvice flycheck-buffer (around dont-throw-in-ido-for-fuck-sake activate)
    (condition-case _
        ad-do-it
      (user-error))))

(provide 'cb-compilation)

;; Local Variables:
;; lexical-binding: t
;; End:

;;; cb-compilation.el ends here