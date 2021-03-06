;;; config-parenface.el --- Configure parenface

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

;; Dim parens in programming languages.

;;; Code:

(require 'utils-common)

(cb:install-package 'parenface)

;; Work around issue loading parenface.
(require 'parenface
         (f-join
          (--first (s-matches? "parenface" it) (f-directories package-user-dir))
          "parenface.el"))

;;; Haskell

(add-hook 'haskell-mode-hook 'paren-face-add-keyword)
(add-hook 'inferior-haskell-mode-hook 'paren-face-add-keyword)

;;; Coq

(add-hook 'coq-mode-hook 'paren-face-add-keyword)

(provide 'config-parenface)

;;; config-parenface.el ends here
