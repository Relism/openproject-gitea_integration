import { ChangeDetectionStrategy, Component, Input, OnInit, inject } from '@angular/core';

import { WorkPackageResource } from 'core-app/features/hal/resources/work-package-resource';
import { TabComponent } from 'core-app/features/work-packages/components/wp-tabs/components/wp-tab-wrapper/tab';
import { PathHelperService } from 'core-app/core/path-helper/path-helper.service';

export function giteaTabPath(pathHelper:PathHelperService, workPackage:WorkPackageResource):string {
  return `${pathHelper.projectWorkPackagePath(workPackage.project.id as string, workPackage.id as string)}/gitea`;
}

// The tab content is rendered by Rails (GiteaIntegration::WorkPackageTabComponent) inside this frame.
@Component({
  selector: 'op-gitea-tab',
  template: `
    <turbo-frame [attr.src]="src" id="work-package-gitea-tab-content">
      <op-content-loader viewBox="0 0 100 100">
        <svg:rect x="0" y="0" width="70" height="6" rx="1" />
        <svg:rect x="0" y="10" width="100" height="22" rx="1" />
        <svg:rect x="0" y="36" width="100" height="22" rx="1" />
        <svg:rect x="0" y="62" width="100" height="22" rx="1" />
      </op-content-loader>
    </turbo-frame>
  `,
  changeDetection: ChangeDetectionStrategy.OnPush,
  standalone: false,
})
export class GiteaTabComponent implements OnInit, TabComponent {
  @Input() public workPackage:WorkPackageResource;

  private readonly pathHelper = inject(PathHelperService);

  src:string;

  ngOnInit():void {
    this.src = `${giteaTabPath(this.pathHelper, this.workPackage)}/tab`;
  }
}
