import type { ExperimentConfig } from "@vercel/agent-eval";

export default {
  agent: "claude-code",
  model: "sonnet",
  runs: 1,
  timeout: 300,
  sandbox: "docker",
  copyFiles: "changed",
  setup: async (sandbox: any) => {
    await sandbox.runShell("npm install -g @typescript/native-preview bun");
  },
} satisfies ExperimentConfig;
