import { defineConfig } from 'vitepress';

export default defineConfig({
  title: 'Servus',
  description: 'A framework for disciplined service objects in Ruby and Rails',
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
      { text: 'Testing', link: '/testing/framework-testing' },
      { text: 'Production', link: '/production/overview' },
      { text: 'Recipes', link: '/recipes/ravenpay-walkthrough' },
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
        ],
      },
      {
        text: 'Framework Features',
        items: [
          { text: 'Schema Validation', link: '/features/schema-validation' },
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
          { text: 'Background Jobs', link: '/rails/background-jobs' },
        ],
      },
      {
        text: 'Testing',
        items: [
          { text: 'Framework Testing', link: '/testing/framework-testing' },
          { text: 'Guards and Events', link: '/testing/guards-and-events' },
        ],
      },
      {
        text: 'Production Patterns',
        items: [
          { text: 'Overview', link: '/production/overview' },
          { text: 'Service Conventions', link: '/production/service-conventions' },
          { text: 'Testing Conventions', link: '/production/testing-conventions' },
          { text: 'Adoption Path', link: '/production/adoption-path' },
        ],
      },
      {
        text: 'Recipes and Migration',
        items: [
          { text: 'Common Patterns', link: '/recipes/common-patterns' },
          { text: 'RavenPay Walkthrough', link: '/recipes/ravenpay-walkthrough' },
          { text: 'Migration', link: '/recipes/migration' },
        ],
      },
      {
        text: 'Reference',
        items: [
          { text: 'Configuration Reference', link: '/reference/configuration' },
          { text: 'Controller Helpers', link: '/reference/controller-helpers' },
          { text: 'Guard Naming', link: '/reference/guard-naming' },
          { text: 'Generators', link: '/reference/generators' },
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
  },
});
