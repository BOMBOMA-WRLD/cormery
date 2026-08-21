export class PromptManager {
  render(template: string, variables: Record<string, string>): string {
    return template.replace(/\\{\\{(\\w+)\\}\\}/g, (_, key: string) => variables[key] ?? '');
  }
}
