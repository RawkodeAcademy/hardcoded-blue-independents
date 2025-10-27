# Namespace
apiVersion: v1
kind: Namespace
metadata:
  name: ${NAMESPACE}
---
# Common labels
# We will create one Deployment+Service per microservice key and one for the aggregator
# Microservices all use the same image binary with SERVICE env var selecting behavior
# Each service listens on port 8080 and exposes `/healthz` and `/op`

# normalized
apiVersion: apps/v1
kind: Deployment
metadata:
  name: normalized
  namespace: ${NAMESPACE}
  labels: { app: normalized }
spec:
  replicas: 1
  selector:
    matchLabels: { app: normalized }
  template:
    metadata:
      labels: { app: normalized }
    spec:
      containers:
        - name: service
          image: ${IMAGE_NORMALIZED}
          imagePullPolicy: Always
          env:
            - name: SERVICE
              value: "normalized"
            - name: PORT
              value: "8080"
          ports:
            - containerPort: 8080
          readinessProbe:
            httpGet: { path: /healthz, port: 8080 }
            initialDelaySeconds: 3
            periodSeconds: 5
          livenessProbe:
            httpGet: { path: /healthz, port: 8080 }
            initialDelaySeconds: 10
            periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: normalizer
  namespace: ${NAMESPACE}
  labels: { app: normalized }
spec:
  selector: { app: normalized }
  ports:
    - name: http
      port: 8080
      targetPort: 8080
---
# transliterated
apiVersion: apps/v1
kind: Deployment
metadata:
  name: transliterated
  namespace: ${NAMESPACE}
  labels: { app: transliterated }
spec:
  replicas: 1
  selector:
    matchLabels: { app: transliterated }
  template:
    metadata:
      labels: { app: transliterated }
    spec:
      containers:
        - name: service
          image: ${IMAGE_TRANSLITERATED}
          imagePullPolicy: Always
          env:
            - name: SERVICE
              value: "transliterated"
            - name: PORT
              value: "8080"
          ports:
            - containerPort: 8080
          readinessProbe:
            httpGet: { path: /healthz, port: 8080 }
            initialDelaySeconds: 3
            periodSeconds: 5
          livenessProbe:
            httpGet: { path: /healthz, port: 8080 }
            initialDelaySeconds: 10
            periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: transliterator
  namespace: ${NAMESPACE}
  labels: { app: transliterated }
spec:
  selector: { app: transliterated }
  ports:
    - name: http
      port: 8080
      targetPort: 8080
---
# slug
apiVersion: apps/v1
kind: Deployment
metadata:
  name: slug
  namespace: ${NAMESPACE}
  labels: { app: slug }
spec:
  replicas: 1
  selector:
    matchLabels: { app: slug }
  template:
    metadata:
      labels: { app: slug }
    spec:
      containers:
        - name: service
          image: ${IMAGE_SLUG}
          imagePullPolicy: Always
          env:
            - name: SERVICE
              value: "slug"
            - name: PORT
              value: "8080"
          ports:
            - containerPort: 8080
          readinessProbe:
            httpGet: { path: /healthz, port: 8080 }
            initialDelaySeconds: 3
            periodSeconds: 5
          livenessProbe:
            httpGet: { path: /healthz, port: 8080 }
            initialDelaySeconds: 10
            periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: slug
  namespace: ${NAMESPACE}
  labels: { app: slug }
spec:
  selector: { app: slug }
  ports:
    - name: http
      port: 8080
      targetPort: 8080
---
# tokens
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tokens
  namespace: ${NAMESPACE}
  labels: { app: tokens }
spec:
  replicas: 1
  selector:
    matchLabels: { app: tokens }
  template:
    metadata:
      labels: { app: tokens }
    spec:
      containers:
        - name: service
          image: ${IMAGE_TOKENS}
          imagePullPolicy: Always
          env:
            - name: SERVICE
              value: "tokens"
            - name: PORT
              value: "8080"
          ports:
            - containerPort: 8080
          readinessProbe:
            httpGet: { path: /healthz, port: 8080 }
            initialDelaySeconds: 3
            periodSeconds: 5
          livenessProbe:
            httpGet: { path: /healthz, port: 8080 }
            initialDelaySeconds: 10
            periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: tokens
  namespace: ${NAMESPACE}
  labels: { app: tokens }
spec:
  selector: { app: tokens }
  ports:
    - name: http
      port: 8080
      targetPort: 8080
---
# unique_words
apiVersion: apps/v1
kind: Deployment
metadata:
  name: unique-words
  namespace: ${NAMESPACE}
  labels: { app: unique-words }
spec:
  replicas: 1
  selector:
    matchLabels: { app: unique-words }
  template:
    metadata:
      labels: { app: unique-words }
    spec:
      containers:
        - name: service
          image: ${IMAGE_UNIQUE_WORDS}
          imagePullPolicy: Always
          env:
            - name: SERVICE
              value: "unique_words"
            - name: PORT
              value: "8080"
          ports:
            - containerPort: 8080
          readinessProbe:
            httpGet: { path: /healthz, port: 8080 }
            initialDelaySeconds: 3
            periodSeconds: 5
          livenessProbe:
            httpGet: { path: /healthz, port: 8080 }
            initialDelaySeconds: 10
            periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: unique-words
  namespace: ${NAMESPACE}
  labels: { app: unique-words }
spec:
  selector: { app: unique-words }
  ports:
    - name: http
      port: 8080
      targetPort: 8080
---
# bigram_count
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bigram-count
  namespace: ${NAMESPACE}
  labels: { app: bigram-count }
spec:
  replicas: 1
  selector:
    matchLabels: { app: bigram-count }
  template:
    metadata:
      labels: { app: bigram-count }
    spec:
      containers:
        - name: service
          image: ${IMAGE_BIGRAM_COUNT}
          imagePullPolicy: Always
          env:
            - name: SERVICE
              value: "bigram_count"
            - name: PORT
              value: "8080"
          ports:
            - containerPort: 8080
          readinessProbe:
            httpGet: { path: /healthz, port: 8080 }
            initialDelaySeconds: 3
            periodSeconds: 5
          livenessProbe:
            httpGet: { path: /healthz, port: 8080 }
            initialDelaySeconds: 10
            periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: bigram-count
  namespace: ${NAMESPACE}
  labels: { app: bigram-count }
spec:
  selector: { app: bigram-count }
  ports:
    - name: http
      port: 8080
      targetPort: 8080
---
# char_count
apiVersion: apps/v1
kind: Deployment
metadata:
  name: char-count
  namespace: ${NAMESPACE}
  labels: { app: char-count }
spec:
  replicas: 1
  selector:
    matchLabels: { app: char-count }
  template:
    metadata:
      labels: { app: char-count }
    spec:
      containers:
        - name: service
          image: ${IMAGE_CHAR_COUNT}
          imagePullPolicy: Always
          env:
            - name: SERVICE
              value: "char_count"
            - name: PORT
              value: "8080"
          ports:
            - containerPort: 8080
          readinessProbe:
            httpGet: { path: /healthz, port: 8080 }
            initialDelaySeconds: 3
            periodSeconds: 5
          livenessProbe:
            httpGet: { path: /healthz, port: 8080 }
            initialDelaySeconds: 10
            periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: char-count
  namespace: ${NAMESPACE}
  labels: { app: char-count }
spec:
  selector: { app: char-count }
  ports:
    - name: http
      port: 8080
      targetPort: 8080
---
# unique_chars
apiVersion: apps/v1
kind: Deployment
metadata:
  name: unique-chars
  namespace: ${NAMESPACE}
  labels: { app: unique-chars }
spec:
  replicas: 1
  selector:
    matchLabels: { app: unique-chars }
  template:
    metadata:
      labels: { app: unique-chars }
    spec:
      containers:
        - name: service
          image: ${IMAGE_UNIQUE_CHARS}
          imagePullPolicy: Always
          env:
            - name: SERVICE
              value: "unique_chars"
            - name: PORT
              value: "8080"
          ports:
            - containerPort: 8080
          readinessProbe:
            httpGet: { path: /healthz, port: 8080 }
            initialDelaySeconds: 3
            periodSeconds: 5
          livenessProbe:
            httpGet: { path: /healthz, port: 8080 }
            initialDelaySeconds: 10
            periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: unique-chars
  namespace: ${NAMESPACE}
  labels: { app: unique-chars }
spec:
  selector: { app: unique-chars }
  ports:
    - name: http
      port: 8080
      targetPort: 8080
---
# hash64
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hash64
  namespace: ${NAMESPACE}
  labels: { app: hash64 }
spec:
  replicas: 1
  selector:
    matchLabels: { app: hash64 }
  template:
    metadata:
      labels: { app: hash64 }
    spec:
      containers:
        - name: service
          image: ${IMAGE_HASH64}
          imagePullPolicy: Always
          env:
            - name: SERVICE
              value: "hash64"
            - name: PORT
              value: "8080"
          ports:
            - containerPort: 8080
          readinessProbe:
            httpGet: { path: /healthz, port: 8080 }
            initialDelaySeconds: 3
            periodSeconds: 5
          livenessProbe:
            httpGet: { path: /healthz, port: 8080 }
            initialDelaySeconds: 10
            periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: hash64
  namespace: ${NAMESPACE}
  labels: { app: hash64 }
spec:
  selector: { app: hash64 }
  ports:
    - name: http
      port: 8080
      targetPort: 8080
---
# entropy
apiVersion: apps/v1
kind: Deployment
metadata:
  name: entropy
  namespace: ${NAMESPACE}
  labels: { app: entropy }
spec:
  replicas: 1
  selector:
    matchLabels: { app: entropy }
  template:
    metadata:
      labels: { app: entropy }
    spec:
      containers:
        - name: service
          image: ${IMAGE_ENTROPY}
          imagePullPolicy: Always
          env:
            - name: SERVICE
              value: "entropy"
            - name: PORT
              value: "8080"
          ports:
            - containerPort: 8080
          readinessProbe:
            httpGet: { path: /healthz, port: 8080 }
            initialDelaySeconds: 3
            periodSeconds: 5
          livenessProbe:
            httpGet: { path: /healthz, port: 8080 }
            initialDelaySeconds: 10
            periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: entropy
  namespace: ${NAMESPACE}
  labels: { app: entropy }
spec:
  selector: { app: entropy }
  ports:
    - name: http
      port: 8080
      targetPort: 8080
---
# palindrome
apiVersion: apps/v1
kind: Deployment
metadata:
  name: palindrome
  namespace: ${NAMESPACE}
  labels: { app: palindrome }
spec:
  replicas: 1
  selector:
    matchLabels: { app: palindrome }
  template:
    metadata:
      labels: { app: palindrome }
    spec:
      containers:
        - name: service
          image: ${IMAGE_PALINDROME}
          imagePullPolicy: Always
          env:
            - name: SERVICE
              value: "palindrome"
            - name: PORT
              value: "8080"
          ports:
            - containerPort: 8080
          readinessProbe:
            httpGet: { path: /healthz, port: 8080 }
            initialDelaySeconds: 3
            periodSeconds: 5
          livenessProbe:
            httpGet: { path: /healthz, port: 8080 }
            initialDelaySeconds: 10
            periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: palindrome
  namespace: ${NAMESPACE}
  labels: { app: palindrome }
spec:
  selector: { app: palindrome }
  ports:
    - name: http
      port: 8080
      targetPort: 8080
---
# aggregator
apiVersion: apps/v1
kind: Deployment
metadata:
  name: aggregator
  namespace: ${NAMESPACE}
  labels: { app: aggregator }
spec:
  replicas: 1
  selector:
    matchLabels: { app: aggregator }
  template:
    metadata:
      labels: { app: aggregator }
    spec:
      containers:
        - name: aggregator
          image: ${IMAGE_AGGREGATOR}
          imagePullPolicy: Always
          env:
            - { name: PORT, value: "8080" }
            - { name: NORMALIZER_URL, value: "http://normalizer.${NAMESPACE}.svc.cluster.local:8080/op" }
            - { name: TRANSLITERATOR_URL, value: "http://transliterator.${NAMESPACE}.svc.cluster.local:8080/op" }
            - { name: SLUG_URL, value: "http://slug.${NAMESPACE}.svc.cluster.local:8080/op" }
            - { name: TOKENS_URL, value: "http://tokens.${NAMESPACE}.svc.cluster.local:8080/op" }
            - { name: UNIQUE_WORDS_URL, value: "http://unique-words.${NAMESPACE}.svc.cluster.local:8080/op" }
            - { name: BIGRAM_COUNT_URL, value: "http://bigram-count.${NAMESPACE}.svc.cluster.local:8080/op" }
            - { name: CHAR_COUNT_URL, value: "http://char-count.${NAMESPACE}.svc.cluster.local:8080/op" }
            - { name: UNIQUE_CHARS_URL, value: "http://unique-chars.${NAMESPACE}.svc.cluster.local:8080/op" }
            - { name: HASH64_URL, value: "http://hash64.${NAMESPACE}.svc.cluster.local:8080/op" }
            - { name: ENTROPY_URL, value: "http://entropy.${NAMESPACE}.svc.cluster.local:8080/op" }
            - { name: PALINDROME_URL, value: "http://palindrome.${NAMESPACE}.svc.cluster.local:8080/op" }
          ports:
            - containerPort: 8080
          readinessProbe:
            httpGet: { path: /healthz, port: 8080 }
            initialDelaySeconds: 3
            periodSeconds: 5
          livenessProbe:
            httpGet: { path: /healthz, port: 8080 }
            initialDelaySeconds: 10
            periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: aggregator
  namespace: ${NAMESPACE}
  labels: { app: aggregator }
spec:
  selector: { app: aggregator }
  ports:
    - name: http
      port: 8080
      targetPort: 8080
