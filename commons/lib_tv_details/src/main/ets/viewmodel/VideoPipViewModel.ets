import { AppStorageV2 } from '@kit.ArkUI';
import {  BaseViewModel } from 'lib_common';
import { PiPWindowModel, VideoCardPlayerController } from 'module_swipeplayer';

const TAG = '[VideoPipViewModel]'

@ObservedV2
export class VideoPipViewModel extends BaseViewModel {
  // 保留 PiPWindowModel 实例：详情页 landscapeListener 复用其 navDestinationUpdateListeners（横屏监听转发）
  @Trace pipWindowModel: PiPWindowModel = AppStorageV2.connect(PiPWindowModel, () => new PiPWindowModel())!;
  context: Context | undefined = undefined
  videoCardPlayerController: VideoCardPlayerController = new VideoCardPlayerController();
  @Trace mXComponentController: XComponentController | undefined = undefined;
  @Trace curState: string = '';
  @Trace videoId: string = '';

  public setContext(context: Context) {
    this.context = context
  }

  public setMXComponentController(mXComponentController: XComponentController) {
    this.mXComponentController = mXComponentController
  }

  public getVideoCardPlayerController() {
    return this.videoCardPlayerController
  }
}
