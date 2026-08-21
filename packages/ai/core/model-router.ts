export interface ModelRoute {
  model: string;
  provider: string;
}

export class ModelRouter {
  constructor(private readonly defaultRoute: ModelRoute) {}

  route(): ModelRoute {
    return this.defaultRoute;
  }
}
