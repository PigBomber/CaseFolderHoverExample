import { RouterMap, RouterUtils } from 'lib_common';

@Entry
@Component
struct Index {
  aboutToAppear(): void {
    // 启动直接进入视频详情页（Mock 数据 television_1）
    let routerParams: Record<string, string> = {
      'avId': 'television_1',
    };
    RouterUtils.pushPathByName(RouterMap.VIDEO_PROGRAM_DETAILS, routerParams);
  }

  build() {
    Navigation(RouterUtils.getStack()) {
    }
    .hideTitleBar(true)
    .mode(NavigationMode.Stack)
  }
}
