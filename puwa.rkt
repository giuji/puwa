#!/usr/bin/racket
#lang racket

(require racket/os)

;; Cmdline arguments
(define config-file (make-parameter (string-append (gethostname) ".rkt")))

(define parser
  (command-line
   #:usage-help
   "my weird software"
   #:once-each
   [("-c" "--config-file") HOST
                    "Set what host config file to use"
                    (config-file (string-append  HOST ".rkt"))]
   #:args () (void)))

(define dotfiles-dir "dots")
(define config-dir "host-config")
(define config-file-path (build-path config-dir (config-file)))

;; Check for files
(define (checks)
  (define (exists? path)
    (or (directory-exists? path) (file-exists? path)))

  (define (path-error path)
    (error "No such file or directory:" (path->string path)))

  ;; I want error messages to show absolute path instead of relative
  (let* ((abs-dots-path (build-path (current-directory) dotfiles-dir))
        (abs-conf-dir-path (build-path (current-directory) config-dir))
        (abs-conf-file-path (build-path abs-conf-dir-path (config-file))))
    (cond ((not (exists? abs-dots-path)) (path-error abs-dots-path))
          ((not (exists? abs-conf-dir-path)) (path-error abs-conf-dir-path))
          ((not (exists? abs-conf-file-path)) (path-error abs-conf-file-path))
          ((null? (directory-list abs-dots-path)) (error "Dotfiles directory is empty:"
                                                         (path->string abs-dots-path)))
          (else (printf "~a~a\n" "Using " (config-file))))))


;; List all file inside a directory and all its subdirectories
(define (recursive-file-list dir)
  (filter file-exists?
          (for/list ([file (in-directory dir)])
            file)))                                    

;; Replace dots/ with /home/<username>/
(define (target-path path)
  (define (accumulate proc list) ; straight from sicp, i love this function
  (if (null? (cdr list))
      (car list)
      (proc (car list)
            (accumulate proc (cdr list)))))
  
  (build-path (find-system-path 'home-dir)
              (accumulate build-path (cdr (explode-path path)))))

;; Idk why this works read function is magical
(define (read-config-file path)
  (call-with-input-file path
    (lambda (fp)
      (port->list read fp))))

;; https://docs.racket-lang.org/guide/eval.html#%28part._namespaces%29
(define ns (make-base-namespace))
;; Returns hash-table from list of define expressions
(define (parse-define-expressions exprs)
  (make-hash (map (lambda (expr)
                    (match expr
                      [(list 'define symbol value) (cons (symbol->string symbol)
                                                         (eval value ns))]
                      [_ (error "Expression must be a `define` statement:" expr)]))
                  exprs)))

;; Actual templating
(define (template-substitution str parsed-hash)
  ;; Return list of tokens that need to be replaced (words between {{{{}}}})
  (define (tokens-to-replace str)
    (regexp-match* #rx"{{{[-a-zA-z_]+}}}" str))

  ;; Given a token, return its matching value from the parsed hash table
  (define (replacement-value token replacement-hash)
    ;; regexp-replace* wants a string so we need to format as such
    (format "~a" (hash-ref replacement-hash
                           (car (regexp-match #rx"[-a-zA-Z_]+" token)))))
                           ;; TODO add failure function that returns name of the
                           ;; file containing the unbound token

  (define (replace-occurencies str tokens-list values-hash)
    (if (null? tokens-list)
        str
        (replace-occurencies (regexp-replace* (car tokens-list)
                                              str
                                              (lambda (t)
                                                (replacement-value t values-hash)))
                             (cdr tokens-list)
                             values-hash)))

  (replace-occurencies str (tokens-to-replace str) parsed-hash))

;; File operations
(define (read-file path)
  (call-with-input-file path
    (lambda (fp)
      (port->string fp #:close? #f))))
      ; call-with-input-file is gonna handle closing the port

(define (write-file path str)
  (make-parent-directory* path)
  (call-with-output-file path #:exists 'replace
    (lambda (fp)
      (display str fp)))
  (printf "~a~a\n" "Wrote file: " path))

;; Main function
(define (render-file-list paths-list)
  (checks)

  (for ([path paths-list])
    (write-file (target-path path)
                (template-substitution (read-file path)
                                       (parse-define-expressions
                                         (read-config-file config-file-path))))))

(render-file-list (recursive-file-list dotfiles-dir))
(printf "~a\n" "Done!!")
