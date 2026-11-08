import { CUSTOM_ELEMENTS_SCHEMA, Injector, NgModule, inject } from '@angular/core';
import { from, Observable } from 'rxjs';

import { OpSharedModule } from 'core-app/shared/shared.module';
import { WorkPackageResource } from 'core-app/features/hal/resources/work-package-resource';
import { PathHelperService } from 'core-app/core/path-helper/path-helper.service';
import { WorkPackageTabsService } from 'core-app/features/work-packages/components/wp-tabs/services/wp-tabs/wp-tabs.service';

import { GiteaTabComponent, giteaTabPath } from './gitea-tab.component';

function giteaCount(workPackage:WorkPackageResource, injector:Injector):Observable<number> {
  const url = `${giteaTabPath(injector.get(PathHelperService), workPackage)}/count`;
  return from(
    fetch(url, { headers: { Accept: 'application/json' }, credentials: 'same-origin' })
      .then((response) => (response.ok ? response.json() as Promise<{ count:number }> : { count: 0 }))
      .then(({ count }) => count),
  );
}

@NgModule({
  imports: [OpSharedModule],
  declarations: [GiteaTabComponent],
  exports: [GiteaTabComponent],
  schemas: [CUSTOM_ELEMENTS_SCHEMA],
})
export class PluginModule {
  constructor() {
    inject(WorkPackageTabsService).registerBefore('watchers', {
      component: GiteaTabComponent,
      name: I18n.t('js.gitea_integration.tab_name'),
      id: 'gitea',
      displayable: (workPackage) => !!workPackage.gitea,
      count: giteaCount,
    });
  }
}
