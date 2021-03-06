;;; -*- mode: Lisp; Syntax: Common-Lisp; -*-
;;;
;;; Copyright (c) 2009 by the authors.
;;;
;;; See LICENCE for details.

(in-package :hu.dwim.walker)

(def (generic e) map-ast (visitor form)
  (:method-combination progn)
  (:method :around (visitor form)
    (let ((new (funcall visitor form)))
      ;; if the visitor returns a new AST node instead of the one being given to it, then stop descending the tree and just return the new one
      ;; giving full control to the visitor over what to do there.
      (if (eq new form)
          (call-next-method)
          new)
      new))
  (:method progn (visitor (form t))
    ;; a primary method with a huge NOP
    ))

(macrolet ((frob (&rest entries)
             `(progn
                ,@(loop
                     :for (type . accessors) :in entries
                     :collect `(defmethod map-ast progn (visitor (form ,type))
                                 ,@(loop
                                      :for accessor :in accessors
                                      :collect `(map-ast visitor (,accessor form))))))))
  (frob
   (cons                      car cdr)
   (application-form          operator-of arguments-of)
   (lambda-function-form      arguments-of)
   (optional-function-argument-form default-value-of)
   (keyword-function-argument-form default-value-of)
   (implicit-progn-mixin      body-of)
   (binder-form-mixin         bindings-of)
   (lexical-variable-binding-form initial-value-of)

   (return-from-form result-of)
   (throw-form                value-of)
   (if-form                   condition-of then-of else-of)
   (multiple-value-call-form  arguments-of function-designator-of)
   (multiple-value-prog1-form first-form-of other-forms-of)
   (progv-form                variables-form-of values-form-of)
   (setq-form                 variable-of value-of)
   ;; go-form: leave it alone, dragons be there (and an infinite recursion, too)
   (the-form                  declared-type-of value-of)
   (unwind-protect-form       protected-form-of cleanup-form-of)))

(def (function e) collect-variable-references (top-form &key (type 'variable-reference-form))
  (let ((result (list)))
    (map-ast (lambda (form)
               (when (typep form type)
                 (push form result))
               form)
             top-form)
    result))

(def function clear-binding-usage-annotation (top-form)
  (map-ast (lambda (form)
             (when (typep form 'name-definition-form)
               (setf (usages-of form) nil))
             form)
           top-form))

(def generic mark-binding-usage (form)
  (:method-combination progn)
  (:method progn ((form t)))
  (:method progn ((form walked-lexical-variable-reference-form))
    (push form (usages-of (definition-of form))))
  (:method progn ((form walked-lexical-function-object-form))
    (push form (usages-of (definition-of form))))
  (:method progn ((form walked-lexical-application-form))
    (push form (usages-of (definition-of form))))
  (:method progn ((form return-from-form))
    (push form (usages-of (target-block-of form))))
  (:method progn ((form go-form))
    (push form (usages-of (tag-of form)))))

(def (function e) annotate-binding-usage (top-form)
  (clear-binding-usage-annotation top-form)
  (map-ast (lambda (form)
             (mark-binding-usage form)
             form)
           top-form))

