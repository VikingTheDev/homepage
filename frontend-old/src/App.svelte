<script lang="ts">
  import { onMount } from 'svelte';
  import axios from 'axios';

  let message = 'Loading...';
  let timestamp = '';
  let error = '';

  onMount(async () => {
    try {
      console.log('Fetching from /api/example...');
      const response = await axios.get('/api/example');
      console.log('Response:', response.data);
      message = response.data.message;
      timestamp = new Date(response.data.timestamp).toLocaleString();
    } catch (err: any) {
      error = 'Failed to connect to backend: ' + (err.message || String(err));
      console.error('Error fetching data:', err);
    }
  });
</script>

<main>
  <div class="container">
    <h1>VikingThe.Dev</h1>
    <p class="subtitle">Containerized Fullstack Application</p>
    
    <div class="card">
      <h2>Backend Status</h2>
      {#if error}
        <p class="error">{error}</p>
      {:else}
        <p class="message">{message}</p>
        <p class="timestamp">Timestamp: {timestamp}</p>
      {/if}
    </div>

    <div class="tech-stack">
      <h3>Tech Stack</h3>
      <ul>
        <li>🦀 Rust (Axum) Backend</li>
        <li>🎨 Svelte + TypeScript Frontend</li>
        <li>🐘 PostgreSQL Database</li>
        <li>🔴 ValKey Caching</li>
        <li>🔐 HashiCorp Vault Secrets</li>
        <li>🚀 Kubernetes (K3s) Deployment</li>
        <li>📊 Prometheus + Grafana Monitoring</li>
      </ul>
    </div>
  </div>
</main>

<style>
  :global(body) {
    margin: 0;
    padding: 0;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen,
      Ubuntu, Cantarell, 'Open Sans', 'Helvetica Neue', sans-serif;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    min-height: 100vh;
  }

  main {
    display: flex;
    justify-content: center;
    align-items: center;
    min-height: 100vh;
    padding: 2rem;
  }

  .container {
    background: white;
    border-radius: 1rem;
    padding: 3rem;
    max-width: 600px;
    width: 100%;
    box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
  }

  h1 {
    color: #667eea;
    font-size: 3rem;
    margin: 0 0 0.5rem 0;
    text-align: center;
  }

  .subtitle {
    text-align: center;
    color: #666;
    font-size: 1.1rem;
    margin: 0 0 2rem 0;
  }

  .card {
    background: #f7f9fc;
    border-radius: 0.5rem;
    padding: 1.5rem;
    margin: 2rem 0;
  }

  h2 {
    margin: 0 0 1rem 0;
    color: #333;
  }

  .message {
    color: #667eea;
    font-size: 1.2rem;
    font-weight: 500;
    margin: 0.5rem 0;
  }

  .timestamp {
    color: #888;
    font-size: 0.9rem;
    margin: 0.5rem 0 0 0;
  }

  .error {
    color: #e74c3c;
    font-weight: 500;
  }

  .tech-stack {
    margin-top: 2rem;
  }

  h3 {
    color: #333;
    margin: 0 0 1rem 0;
  }

  ul {
    list-style: none;
    padding: 0;
    margin: 0;
  }

  li {
    padding: 0.5rem 0;
    color: #555;
    font-size: 1rem;
  }
</style>
