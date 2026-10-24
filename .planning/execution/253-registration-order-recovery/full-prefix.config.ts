// Collection-only preparation; this does not authorize a native run.
import original from './playwright.config';
const projects = new Set(['admin-eval', 'admin-eval-mobile', 'admin-eval-dark']);
export default {
  ...original,
  projects: original.projects?.filter(project => projects.has(project.name!)).map(project =>
    project.name === 'admin-eval-dark'
      ? {...project, grep: /render bundle: board-mg-(?:[1-8]\/(?:populated|zero|loading|error)|9\/populated)$/}
      : project),
};
