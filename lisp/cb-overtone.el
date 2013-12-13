;;; cb-overtone.el --- Minor mode for Overtone.

;; Copyright (C) 2013 Chris Barrett

;; Author: Chris Barrett <chris.d.barrett@me.com>
;; Version: 20130510.1410

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

;; Minor mode for Overtone.

;;; Code:

(require 'cb-evil)
(require 'cb-mode-groups)
(autoload 'cider-eval "cider-client")
(autoload 'cider-popup-eval-out-handler "cider-interaction")
(autoload 'cider-read-symbol-name "cider-interaction")
(autoload 'cider-tooling-eval "cider-client")
(autoload 'projectile-project-p "projectile")
(autoload 'projectile-project-root "projectile")

(defvar overtone-mode-map
  (let ((km (make-sparse-keymap)))
    (define-key km (kbd "C-c C-g") 'cb:stop-overtone)
    (define-key km (kbd "s-.") 'cb:stop-overtone)
    (define-key km (kbd "C-c C-h") 'odoc)
    km))

(define-minor-mode overtone-mode
  "Provide additional overtone-related functionality for clojure."
  nil " overtone" overtone-mode-map)

(defun maybe-enable-overtone-mode ()
  "Enable `overtone-mode' only if the current buffer or project references overtone."
  (when (and (not overtone-mode)
             (derived-mode-p 'clojure-mode 'cider-repl-mode)
             (cbot:overtone-project-reference-p))
    (overtone-mode t)))

(define-globalized-minor-mode global-overtone-mode overtone-mode
  maybe-enable-overtone-mode)

(defun cbot:overtone-project-reference-p ()
  "Non-nil if the project.clj imports overtone."
  (-when-let (clj (and (projectile-project-p)
                       (f-join (projectile-project-root) "project.clj")))
    (when (f-exists? clj)
      (s-contains? "overtone" (f-read-text clj)))))

(defun cb:stop-overtone ()
  "Stop synthesis."
  (interactive)
  (cider-eval "(stop)" nil)
  (message "Synthesis stopped."))

(add-hook 'clojure-mode-hook 'global-overtone-mode)

;; Documentaion search.

(defun overtone-doc-handler (symbol)
  "Create a handler to lookup documentation for SYMBOL."
  (let ((form (format "(odoc %s)" symbol))
        (doc-buffer (cider-popup-buffer cider-doc-buffer t)))
    (cider-tooling-eval form
                        (cider-popup-eval-out-handler doc-buffer)
                        nrepl-buffer-ns)))

(defun overtone-doc (query)
  "Open a window with the docstring for the given QUERY.
Defaults to the symbol at point.  With prefix arg or no symbol
under point, prompts for a var."
  (interactive "P")
  (cider-read-symbol-name "Symbol: " 'overtone-doc-handler query))

(defalias 'odoc 'overtone-doc)

(provide 'cb-overtone)

;; Local Variables:
;; End:

;;; cb-overtone.el ends here
