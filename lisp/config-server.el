;;; config-server.el --- Configuration for emacs server

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

;; Configuration for emacs server

;;; Code:

(require 'server)
(require 'utils-common)

(hook-fn 'after-init-hook
  (unless (or noninteractive (server-running-p))
    (server-start)))

(defun cb-server:configure-frame (&rest frame)
  "Disable themeing for console emacsclient."
  (unless (display-graphic-p)
    (let ((fm (or (car frame) (selected-frame)))
          (tranparent "ARGBBB000000")
          (blue "#168DCC")
          )
      (set-face-foreground 'default nil fm)
      (set-face-background 'default tranparent fm)
      (set-face-background 'menu blue fm)
      (set-face-foreground 'menu "white" fm)

      (when (featurep 'hl-line)
        (set-face-background 'hl-line tranparent fm))

      (set-face-background 'fringe tranparent fm)
      (set-face-background 'cursor "#2F4F4F" fm)
      ;; Modeline
      (set-face-foreground 'mode-line-filename "white" fm)
      (set-face-foreground 'mode-line-position "white" fm)
      (set-face-foreground 'mode-line-mode "black" fm)
      (set-face-bold 'mode-line-mode t fm)
      (set-face-background 'mode-line blue fm)
      (set-face-background 'mode-line blue fm)

      (when (featurep 'smartparens)
        (set-face-background 'sp-pair-overlay-face "green" fm))
      (when (featurep 'org)
        (set-face-background 'org-block-begin-line tranparent fm)
        (set-face-background 'org-block-end-line tranparent fm)
        (set-face-background 'org-block-background tranparent fm)))))

(defadvice server-create-window-system-frame (after configure-frame activate)
  "Set custom frame colours when creating the first frame on a display"
  (cb-server:configure-frame))

(add-hook 'after-make-frame-functions 'cb-server:configure-frame t)

(provide 'config-server)

;;; config-server.el ends here
