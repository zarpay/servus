1. Change rescue_from to allow multiple declarations, each with a specific mapping to the specified errors.

2. Make sure Async Jobs don't retry when the job class cant be constantized.

3. Improve error handling with an error registry that can be referenced by codes as opposed to fully qualified class names.
