1. Make sure Async Jobs don't retry when the job class cant be constantized.

2. Improve error handling with an error registry that can be referenced by codes as opposed to fully qualified class names.

3. Update generators to not make schema files and instead add schemas to schema: method in generators.
