import { ValueType } from '@kit.ArkData';
import { AppStorageV2, uiObserver, window } from '@kit.ArkUI';
import { AVCastPicker } from '@kit.AVSessionKit';
import { UtilLog } from '@hw-agconnect/util-log';
import {
  PageNameEnum, VideoCard, VideoNetworkModel,
} from 'module_swipeplayer';
import { AvModel, AvSection, HomeServiceApi } from 'lib_tv_apis';
import {
  CircleButtonModifier,
  Constants,
  GridRowColSetting,
  NavHeaderTitleBar,
  RouterMap,
  RouterUtils,
} from 'lib_common';
import { VideoData } from '../model/VideoModel';
import { VideoVM } from '../viewmodel/VideoViewModel';
import { VideoPipViewModel } from '../viewmodel/VideoPipViewModel';
import { VideoAxisList } from '../components/VideoAxisList';
import { AvViewModel } from '../viewmodel/AvViewModel';

@Builder
export function VideoProgramDetailsBuilder() {
  VideoProgramDetails()
}

const TAG = '[VideoProgramDetails]';

@ComponentV2
export struct VideoProgramDetails {
  @Local detailData: VideoData | undefined
  @Local videoDetails: AvModel | undefined
  @Local seek: number = 0
  @Local currentProgress: number = 0;
  @Local videoPipModel: VideoPipViewModel = new VideoPipViewModel()
  @Local sectionIndex: number = -1
  @Local videoId: string = ''
  videoVM: VideoVM = new VideoVM(this.getUIContext())
  avViewModel: AvViewModel = new AvViewModel()
  buttonModifier: CircleButtonModifier = new CircleButtonModifier();
  private landscapeListener = (info: uiObserver.NavDestinationInfo) => {
    this.videoPipModel.pipWindowModel.navDestinationUpdateListeners.forEach((callback, key) => {
      if (key === 'landscapeListener') {
        callback(info)
      }
    })
  }

  @Monitor('sectionIndex')
  sectionIndexChange() {
    this.detailData = new VideoData(this.videoDetails!.section[this.sectionIndex], this.detailData?.title)
  }

  @Monitor('canPlay')
  handlePlayAndPause() {
    // 停留在详情页时，不能播放的场景需要屏蔽自由横竖屏旋转
    const lastName = RouterUtils.getLastPathName();
    if (lastName !== PageNameEnum.VIDEO_LANDSCAPE_PAGE) {
      this.videoVM.setOrientation();
    }
  }

  // WindowStage生命周期变化的监听回调函数（PiP 已剥离，保留骨架供 windowStageEventListeners 注册）
  private windowStageEventCallback = (type: window.WindowStageEventType) => {
  }

  async aboutToAppear(): Promise<void> {
    // 无感监听路由变化
    uiObserver.on('navDestinationUpdate', this.landscapeListener);
    this.videoPipModel.setContext(this.getUIContext().getHostContext() as Context)
    this.videoVM.windowStageModel.windowStageEventListeners.delete('VideoProgramDetails');
    this.videoVM.windowStageModel.windowStageEventListeners.set('VideoProgramDetails', (type) => {
      this.windowStageEventCallback(type)
    });
    this.videoVM.windowStageModel.windowStageEventListeners.delete('VideoDetailsBackground');
    this.videoVM.windowStageModel.windowStageEventListeners.set('VideoDetailsBackground', (type) => {
      // 应用回到后台则暂停视频
      if ([window.WindowStageEventType.HIDDEN,window.WindowStageEventType.PAUSED].includes(type)) {
        this.videoPipModel.videoCardPlayerController.pause()
      }
    });
  }

  aboutToDisappear(): void {
    UtilLog.debug(TAG, 'aboutToDisappear');
    uiObserver.off('navDestinationUpdate', this.landscapeListener)
  }

  backIntercept() {
    RouterUtils.pop(this.videoDetails);
  }

  @Builder
  videoInfo() {
    Column({ space: 12 }) {
      Column({ space: 4 }) {
        Text(this.detailData?.title)
          .fontColor($r('sys.color.font_primary'))
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
        Text(this.detailData?.updateTime)
          .fontColor($r('sys.color.font_tertiary'))
          .fontSize(12)
          .fontWeight(FontWeight.Regular)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Flex({ justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Center }) {
        Row({ space: 12 }) {
          Image(this.videoDetails?.coverUrl)
            .width(40)
            .height(40)
            .borderRadius('50%')
            .clip(true)
          Text(this.videoDetails?.title)
            .fontColor($r('sys.color.font_primary'))
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
        }

        Button(this.videoDetails?.isFollow ? '已订阅' : '订阅')
          .fontColor(this.videoDetails?.isFollow ? '#EB5544' : $r('sys.color.font_on_primary'))
          .fontSize($r('sys.float.Body_M'))
          .fontWeight(FontWeight.Medium)
          .backgroundColor(this.videoDetails?.isFollow ? $r('sys.color.comp_background_tertiary') : '#EB5544')
          .width(72)
          .height(28)
          .padding(0)
          .onClick(() => {
            // 订阅点击事件已剥离（保留按钮 UX）
          })

      }
    }
    .width('100%')
    .margin({ top: 8, bottom: 16 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  customCastBuilder() {
    Button() {
      SymbolGlyph($r('sys.symbol.wireless_projection'))
        .fontColor([$r('sys.color.font_on_primary')])
        .fontWeight(FontWeight.Normal)
        .fontSize(24)
    }
    .attributeModifier(this.buttonModifier)
    .backgroundColor($r('app.color.circle_btn_bg'))
    .accessibilityText('投屏')
  }

  @Builder
  titleBar() {
    Row({ space: Constants.SPACE_S }) {
      Blank()

      AVCastPicker({
        customPicker: () => this.customCastBuilder(),
      })
        .width(40)
        .height(40)
    }
    .padding({
      left: Constants.PADDING_L,
      right: Constants.PADDING_L,
      top: Constants.PADDING_S,
    })
    .width(Constants.FULL_PERCENT)
  }

  @Builder
  ContentBuilder() {
    Column() {
      GridRow(GridRowColSetting.DEFAULT_GRID_ROW_OPTIONS) {
        GridCol({
          span: GridRowColSetting.DEFAULT_CENTER_COL_SPAN,
        }) {
          Column() {
            Stack({ alignContent: Alignment.TopStart }) {
              Column() {
                if (this.videoDetails) {
                  VideoCard({
                    currentIndex: 0,
                    index: 0,
                    videoData: this.detailData,
                    isShown: true,
                    isLandscape: this.videoVM.displayModel.isLandscape,
                    videoNetwork: this.videoVM.networkModel as VideoNetworkModel,
                    currentBreakpoint: this.videoVM.breakPointModel.currentBreakpoint,
                    videoCardPlayerController: this.videoPipModel.getVideoCardPlayerController(),
                    isFromDetailCard: true,
                    canChangeSlide: true,
                    pathStack: RouterUtils.getStack(),
                    themeColor: '#EB5544',
                    enableAVSession: true,
                    enableCastPlay: true,
                    fullScreenIcon: $r('app.media.ic_sys_full_screen'),
                    isNeedMuteIcon: true,
                    isMute: this.videoVM.isMute,
                    onMute: (value) => {
                      this.videoVM.setMute(value)
                    },
                    playerStateCallback: (state: string, id: string) => {
                      if (id === this.detailData?.id && state === 'prepared') {
                        if (this.seek) {
                          this.videoPipModel.videoCardPlayerController.seek(this.seek);
                          this.currentProgress = this.seek;
                        }
                      }
                    },
                    timeUpdateCallback: (timeMs: number) => {
                      this.currentProgress = timeMs;
                    },
                    xComponentReadyCallback: (controller: XComponentController) => {
                      this.videoPipModel.setMXComponentController(controller)
                    },
                  })
                }
              }
              .width(Constants.FULL_PERCENT)
              .height(this.videoVM.videoBoxHeight)
              .aspectRatio(this.videoVM.videoBoxAspectRatio)
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Center)
              .backgroundColor(Color.Black)
              .id('detailsVideoCard')

              this.titleBar()
            }
            .parallelGesture(
              GestureGroup(GestureMode.Exclusive,
                // 双击暂停或播放
                TapGesture({ count: 2 })
                  .onAction((event: GestureEvent) => {
                    if (!event) {
                      return
                    }
                    this.videoPipModel.getVideoCardPlayerController().switchPlayPause()
                  }),
              ),
            )
          }
        }

        GridCol({
          span: {
            sm: 8,
            md: 8,
            lg: 4,
            xl: 4,
          },
        }) {
          Column() {
            this.videoInfo()
            Flex({ justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Center }) {
              Text('往期节目')
                .fontColor($r('sys.color.font_primary'))
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
              Row() {
                Text('全部')
                  .fontColor($r('sys.color.font_secondary'))
                  .fontSize(14)
                  .fontWeight(FontWeight.Regular)
                SymbolGlyph($r('sys.symbol.chevron_right'))
                  .fontColor([$r('sys.color.font_secondary')])
                  .fontWeight(FontWeight.Normal)
                  .fontSize(14)
              }
              .onClick(() => {
                // 「全部」往期节目跳转已剥离（保留入口 UX）
                this.videoPipModel.videoCardPlayerController.pause()
              })
            }
            .margin({ bottom: 8 })

            VideoAxisList({
              videoDetails: this.videoDetails,
              isTvDetails: true,
              sectionIndex: this.sectionIndex!!,
              onVideoChange: (item: AvSection) => {
                const videoData = new VideoData(item, this.videoDetails?.title);
                this.videoPipModel.videoCardPlayerController.videoUrlChange(videoData);
              },
            })
          }
          .layoutWeight(1)
          .padding({ left: 16, right: 16 })
          .id('detailsContent')
        }
      }
      .width(Constants.FULL_PERCENT)
      .layoutWeight(1)
    }
    .layoutWeight(1)
    .backgroundColor($r('sys.color.background_primary'))
  }

  build() {
    NavDestination() {
      this.ContentBuilder()
    }
    .backgroundColor($r('sys.color.background_primary'))
    .hideTitleBar(true)
    .onReady(async (context) => {
      const params = context.pathStack.getParamByName('VideoProgramDetails')[0] as Record<string, ValueType>
      this.videoId = params.avId as string
      this.seek = params.seek as number
      const videoDetails = await HomeServiceApi.queryHomeTelevisionDetails(this.videoId) as AvModel
      this.videoDetails = new AvModel(videoDetails)
      this.detailData = new VideoData(this.videoDetails.section[0], this.videoDetails.title)
      // 详情页进入即播放顶部视频（确保后续进入横屏页时不黑屏）
      setTimeout(() => {
        this.videoPipModel.getVideoCardPlayerController().switchPlayPause()
      }, 1000)
    })
    .onBackPressed(() => {
      this.backIntercept()
      return true
    })
    .onWillShow(() => {
      this.videoVM.setOrientation();
    })
    .onWillDisappear(() => {
      this.videoVM.resetOrientation();
    })
  }
}