import { defineConfig } from 'vitepress';

export default defineConfig({
  base: '/servus/',
  title: 'Servus',
  description: 'A disciplined service-object pattern for Ruby and Rails',
  lang: 'en-US',
  cleanUrls: true,
  lastUpdated: true,
  appearance: false,
  vite: {
    server: {
      allowedHosts: true,
    },
  },
  themeConfig: {
    siteTitle: 'Servus',
    search: {
      provider: 'local',
    },
    nav: [
      { text: 'Home', link: '/' },
      { text: 'Quick Start', link: '/getting-started/' },
      { text: 'Core Concepts', link: '/core/service-objects' },
      { text: 'Features', link: '/features/schema-validation' },
      { text: 'Rails', link: '/rails/controllers' },
      { text: 'Testing', link: '/testing/services' },
      { text: 'Reference', link: '/reference/generators' },
    ],
    sidebar: [
      {
        text: 'Introduction',
        items: [
          { text: 'Home', link: '/' },
          { text: 'Quick Start', link: '/getting-started/' },
          { text: 'The Servus Mental Model', link: '/getting-started/mental-model' },
        ],
      },
      {
        text: 'Core Concepts',
        items: [
          { text: 'Service Objects', link: '/core/service-objects' },
          { text: 'Call Chain', link: '/core/call-chain' },
          { text: 'Responses', link: '/core/responses' },
          { text: 'Composition', link: '/core/composition' },
        ],
      },
      {
        text: 'Features',
        items: [
          { text: 'Schema Validation', link: '/features/schema-validation' },
          { text: 'Shared Schemas', link: '/features/shared-schemas' },
          { text: 'Error Handling', link: '/features/error-handling' },
          { text: 'Async Execution', link: '/features/async-execution' },
          { text: 'Logging', link: '/features/logging' },
          { text: 'Events', link: '/features/event-bus' },
          { text: 'Guards', link: '/features/guards' },
          { text: 'Lazy Resolvers', link: '/features/lazy-resolvers' },
        ],
      },
      {
        text: 'Rails Integration',
        items: [
          { text: 'Controllers', link: '/rails/controllers' },
          { text: 'Generators', link: '/rails/generators' },
          { text: 'Configuration', link: '/rails/configuration' },
          { text: 'Autoloading', link: '/rails/autoloading' },
        ],
      },
      {
        text: 'Testing',
        items: [
          { text: 'Testing Services', link: '/testing/services' },
          { text: 'Testing Guards', link: '/testing/guards' },
          { text: 'Testing Events', link: '/testing/events' },
        ],
      },
      {
        text: 'Reference',
        items: [
          { text: 'Generators', link: '/reference/generators' },
          { text: 'Dry Initializer', link: '/reference/dry-initializer' },
        ],
      },
    ],
    socialLinks: [{ icon: 'github', link: 'https://github.com/zarpay/servus' }],
    outline: {
      level: [2, 3],
      label: 'On this page',
    },
    docFooter: {
      prev: 'Previous page',
      next: 'Next page',
    },
    footer: {
      message: 'Developed at and used extensively by <a href="https://zar.app">ZAR</a>',
      copyright: 'Released under the MIT License',
    },
  },
});
