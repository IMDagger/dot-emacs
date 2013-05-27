;;; cb-web.el --- Configuration for web and Internet stuff

;; Copyright (C) 2013 Chris Barrett

;; Author: Chris Barrett <chris.d.barrett@me.com>
;; Version: 20130527.0018

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

;; Configuration for web and Internet stuff

;;; Code:

(require 'use-package)

(use-package smtpmail
  :commands smtpmail-send-it
  :init
  (setq send-mail-function 'smtpmail-send-it
        message-send-mail-function 'smtpmail-send-it))

(use-package gnus
  :commands gnus
  :defer t
  :config
  (setq gnus-select-method '(nnml "mail")))

(use-package bbdb
  :ensure t
  :defer  t
  :init
  (progn
    (add-hook 'gnus-startup-hook 'bbdb-insinuate-gnus)
    (add-hook 'message-mode-hook 'bbdb-insinuate-mail)
    (setq bbdb-file (concat user-dropbox-directory ".bbdb")))
  :config
  (progn
    (setq
     bbdb-offer-save 1
     bbdb-use-popup  t
     bbdb-electric   t
     bddb-popup-target-lines     1
     bbdb-dwim-net-address-allow-redundancy t
     bbdb-quiet-about-name-mismatches       2
     bbdb-always-add-address     t
     bbdb-canonicalize-redundant-nets-p     t
     bbdb-completion-type nil
     bbdb-complete-name-allow-cycling       t
     bbbd-message-caching-enabled           t
     bbdb-use-alternate-names    t
     bbdb-elided-display         t
     bbdb/mail-auto-create-p     'bbdb-ignore-some-messages-hook
     )
    (bbdb-initialize)))

(use-package bbdb-vcard
  :commands
  (bbdb-vcard-import-file
   bbdb-vcard-import-buffer
   bbdb-vcard-export)
  :config
  ;; HACK: calls functions that appear not to exist.
  (progn
    (defalias 'bbdb-record-Notes 'ignore)
    (defalias 'bbdb-record-set-Notes 'ignore)))

(use-package google-this
  :ensure   t
  :commands google-this
  :diminish google-this-mode
  :init     (bind-key* "M-s" 'google-this)
  :config   (google-this-mode +1))

(use-package w3m
  :ensure   t
  :commands
  (w3m
   w3m-find-file
   w3m-browse-url)
  :init
  (progn
    (setq browse-url-browser-function 'w3m-browse-url)

    (declare-modal-executor w3m
      :command w3m
      :bind "M-W"
      :restore-bindings '("M-W" "M-E"))

    (defun cb:find-window-with-mode (mode)
      "Find the first window whose buffer is in major-mode MODE."
      (get-window-with-predicate
       (lambda (w) (with-current-buffer (window-buffer w)
                     (equal mode major-mode)))))

    (defun cb:w3m-browse-url-as-help (url)
      "Browse the given URL in a help window."
      (interactive
       (list
        (read-string "Go to URL: "
                     (thing-at-point-url-at-point)
                     t)))
      (with-window-restore
        (let ((win (or (cb:find-window-with-mode 'w3m-mode) (split-window))))
          (select-window win)
          (w3m-browse-url url))
        (local-set-key (kbd "q") (command (restore)))))

    (defun cb:w3m-browse-dwim (url)
      "Browse to URL, ensuring it begins with http:// as reqiured by w3m."
      (interactive
       (list
        (read-string "Go to URL: "
                     (thing-at-point-url-at-point)
                     t)))
      (with-window-restore
        (w3m-browse-url
         (if (s-starts-with? "http://" url)
             url
           (concat "http://" url)))
        (local-set-key (kbd "q") (command (restore)))))

    (bind-key* "M-e" 'cb:w3m-browse-dwim)
    )
  :config
  (hook-fn 'w3m-mode-hook
    (buffer-face-set
     `(:family ,(serif-font) :height 130))))

(use-package erc
  :defer t
  :config
  (progn
    (erc-autojoin-mode +1)
    (erc-track-mode +1)
    (setq
     erc-hide-list
     '("JOIN" "PART" "QUIT" "NICK")

     erc-prompt
     (lambda () (format "%s>" (erc-current-nick)))

     erc-track-exclude-types
     '("JOIN" "NICK" "PART" "QUIT" "MODE"
       "324" "329" "332" "333" "353" "477"))))

(provide 'cb-web)

;; Local Variables:
;; lexical-binding: t
;; End:

;;; cb-web.el ends here
