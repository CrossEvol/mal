(define-library (lib types)

(export make-mal-object mal-object? mal-type mal-value mal-value-set! mal-meta
        mal-true mal-false mal-nil
        mal-number mal-string mal-symbol mal-keyword
        mal-list mal-vector mal-map mal-atom

        make-func func-copy func? func-ast func-params func-env
        func-fn func-macro? func-macro?-set! func-meta func-meta-set!

        mal-instance-of? 

        mal-equal? mal-list-equal? mal-map-ref mal-map-equal?)

(import (scheme base))
(import (lib util))

(begin

(define-record-type mal-object
  (make-mal-object type value meta)
  mal-object?
  (type mal-type)
  (value mal-value mal-value-set!)
  (meta mal-meta mal-meta-set!))

(define mal-true (make-mal-object 'true #t #f))
(define mal-false (make-mal-object 'false #f #f))
(define mal-nil (make-mal-object 'nil #f #f))

(define (mal-number n)
  (make-mal-object 'number n #f))

(define (mal-string string)
  (make-mal-object 'string string #f))

(define (mal-symbol name)
  (make-mal-object 'symbol name #f))

(define (mal-keyword name)
  (make-mal-object 'keyword name #f))

(define (mal-list items)
  (make-mal-object 'list items #f))

(define (mal-vector items)
  (make-mal-object 'vector items #f))

(define (mal-map items)
  (make-mal-object 'map items #f))

(define (mal-atom item)
  (make-mal-object 'atom item #f))

(define-record-type func
  (%make-func ast params env fn macro? meta)
  func?
  (ast func-ast)
  (params func-params)
  (env func-env)
  (fn func-fn)
  (macro? func-macro? func-macro?-set!)
  (meta func-meta func-meta-set!))

(define (func-copy f)
  (%make-func (func-ast f)
              (func-params f)
              (func-env f)
              (func-fn f)
              (func-macro? f)
              (func-meta f)))

(define (make-func ast params env fn)
  (%make-func ast params env fn #f #f))

(define (mal-instance-of? x type)
  (and (mal-object? x) (eq? (mal-type x) type)))

(define (mal-equal? a b)
  (let ((a-type (and (mal-object? a) (mal-type a)))
        (a-value (and (mal-object? a) (mal-value a)))
        (b-type (and (mal-object? b) (mal-type b)))
        (b-value (and (mal-object? b) (mal-value b))))
    (cond
     ((or (not a-type) (not b-type))
      mal-false)
     ((and (memq a-type '(list vector))
           (memq b-type '(list vector)))
      (mal-list-equal? (->list a-value) (->list b-value)))
     ((and (eq? a-type 'map) (eq? b-type 'map))
      (mal-map-equal? a-value b-value))
     (else
      (and (eq? a-type b-type)
           (equal? a-value b-value))))))

(define (mal-list-equal? as bs)
  (let loop ((as as)
             (bs bs))
    (cond
     ((and (null? as) (null? bs)) #t)
     ((or (null? as) (null? bs)) #f)
     (else
      (if (mal-equal? (car as) (car bs))
          (loop (cdr as) (cdr bs))
          #f)))))

(define (mal-map-ref key m . default)
  (if (pair? default)
      (alist-ref key m mal-equal? (car default))
      (alist-ref key m mal-equal?)))

(define (mal-map-equal? as bs)
  (if (not (= (length as) (length bs)))
      #f
      (let loop ((as as))
        (if (pair? as)
            (let* ((item (car as))
                   (key (car item))
                   (value (cdr item)))
              (if (mal-equal? (mal-map-ref key bs) value)
                  (loop (cdr as))
                  #f))
            #t))))

)

)
