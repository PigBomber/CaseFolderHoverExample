import { describe, it, expect, Level, beforeAll } from '@ohos/hypium';
import { abilityDelegatorRegistry, Driver, ON } from '@kit.TestKit';
import { Want } from '@kit.AbilityKit';
import { triggerFold, triggerLandscapeHover, sleep } from '../util/FoldTrigger';

const delegator: abilityDelegatorRegistry.AbilityDelegator = abilityDelegatorRegistry.getAbilityDelegator();

/**
 * 导航到横屏播放页（详情页 → 全屏按钮）
 *
 * folded-case-01 启动直接进详情页（VideoProgramDetails），
 * 点击详情页视频卡片的「全屏」按钮（id='fullScreenButton'）进入横屏播放页（LandscapeVideo）。
 *
 * 运行配置：DevEco ohosTest 运行配置 timeout 调到 60000ms。
 */
async function navigateToLandscape(driver: Driver): Promise<void> {
  const want: Want = {
    bundleName: abilityDelegatorRegistry.getArguments().bundleName,
    abilityName: 'EntryAbility'
  };
  await delegator.startAbility(want);
  await driver.waitForComponent(ON.id('detailsVideoCard'), 8000);
  await driver.waitForIdle(2000, 3000);
  await driver.waitForComponent(ON.id('fullScreenButton'), 15000);
  const fullScreenBtn = await driver.findComponent(ON.id('fullScreenButton'));
  await fullScreenBtn.click();
  await driver.waitForComponent(ON.id('upperVideoPlayer'), 8000);
  await driver.waitForIdle(1500, 2000);
}

/**
 * 确保视频处于播放状态：若暂停则点击播放图标恢复
 *
 * 横屏页控制栏 4 秒后自动隐藏（showBar=false），中心播放图标随之 Hidden。
 * 单击手势（handleClickScreen → showBar 翻转）绑定在 lowerControls 上，
 * 故先点击 lowerControls 唤出控制栏，再判定播放态：
 *   centerPlayIcon.getDescription()：'点击暂停'=播放中，'点击播放'=暂停
 */
async function ensurePlaying(driver: Driver): Promise<void> {
  // 点击 lowerControls 唤出控制栏（单击手势绑定在此，触发 handleClickScreen → showBar 翻转）
  const controls = await driver.findComponent(ON.id('lowerControls'));
  await controls.click();
  await sleep(500);
  // 判定播放态并按需恢复
  const playIcon = await driver.findComponent(ON.id('centerPlayIcon'));
  const desc: string = await playIcon.getDescription();
  if (desc === '点击播放') {
    await playIcon.click();
    await sleep(1000);
  }
}

/**
 * Story 悬停态原子化用例
 *
 * base 状态：LandscapeVideo 用普通 Stack，悬停态下视频占满全屏
 * patch 状态：LandscapeVideo 用 FolderStack({ upperItems: ['upperVideoPlayer'] })，
 *             悬停态下视频被系统约束到上半屏（折痕以上）
 *
 * 核心区分点：FolderStack 在悬停态会把 upperItems 约束到上半屏，
 *            Stack 则让视频占满全屏。以下用例从不同几何角度验证这一差异。
 *
 * 前置：必须先切到横屏悬停态（半折+横屏），FolderStack 才会触发上屏约束。
 */
export default function hoverTest() {
  describe('HoverTest', () => {
    let driver: Driver;

    beforeAll(async () => {
      driver = Driver.create();
      // 展开态启动 App 并导航到横屏页，再切悬停态
      await triggerFold('open', 3000);
      await navigateToLandscape(driver);
      await triggerLandscapeHover(driver);
    });

    /**
     * 角度1：悬停态下视频底部在折痕附近（半屏±15%）
     * base(Stack)：视频占满全屏，bottom ≈ 屏底 → FAIL
     * patch(FolderStack)：视频被约束到上半屏，bottom ≈ 半屏（折痕）→ PASS
     */
    it('hover_videoBottomNearHalf', Level.LEVEL3, async (done: Function) => {
      const video = await driver.findComponent(ON.id('upperVideoPlayer'));
      const bounds = await video.getBounds();
      const screen = await driver.getDisplaySize();
      const halfHeight: number = screen.y / 2;
      const tolerance: number = screen.y * 0.15;
      expect(Math.abs(bounds.bottom - halfHeight) <= tolerance).assertTrue();
      done();
    });

    /**
     * 角度2：悬停态下视频高度约为半屏（被约束到上半屏的客观证据）
     * base(Stack)：视频高度 ≈ 屏高 → FAIL
     * patch(FolderStack)：视频高度 ≈ 半屏 → PASS
     */
    it('hover_videoHeightAboutHalf', Level.LEVEL3, async (done: Function) => {
      const video = await driver.findComponent(ON.id('upperVideoPlayer'));
      const bounds = await video.getBounds();
      const screen = await driver.getDisplaySize();
      const halfHeight: number = screen.y / 2;
      const videoHeight: number = bounds.bottom - bounds.top;
      const tolerance: number = screen.y * 0.15;
      expect(Math.abs(videoHeight - halfHeight) <= tolerance).assertTrue();
      done();
    });

    /**
     * 角度3：悬停态下视频中心点在上四分之一区域（视频居上半屏）
     * base(Stack)：视频中心 ≈ 屏幕中央(50%) → FAIL
     * patch(FolderStack)：视频中心 ≈ 1/4 屏高 → PASS
     */
    it('hover_videoCenterInUpperQuarter', Level.LEVEL3, async (done: Function) => {
      const video = await driver.findComponent(ON.id('upperVideoPlayer'));
      const bounds = await video.getBounds();
      const screen = await driver.getDisplaySize();
      const videoCenter: number = (bounds.top + bounds.bottom) / 2;
      // 视频中心应在屏幕上半部（< 40% 屏高，容差到折痕附近）
      expect(videoCenter <= screen.y * 0.40).assertTrue();
      done();
    });

    /**
     * 角度4：悬停态下控制区位于下半屏（视频在上、控制在下，上下分布）
     * base(Stack)：控制层覆盖全屏，中心 ≈ 屏幕中央 → FAIL
     * patch(FolderStack)：控制层在下半屏，中心 > 半屏 → PASS
     */
    it('hover_controlsInLowerHalf', Level.LEVEL3, async (done: Function) => {
      const controls = await driver.findComponent(ON.id('lowerControls'));
      const bounds = await controls.getBounds();
      const screen = await driver.getDisplaySize();
      const halfHeight: number = screen.y / 2;
      const controlsCenter: number = (bounds.top + bounds.bottom) / 2;
      // 控制区中心应在下半屏（> 半屏）
      expect(controlsCenter > halfHeight).assertTrue();
      done();
    });

    /**
     * 角度5：悬停态可靠性——离开悬停（展开）后再次进入悬停，视频仍被约束到上半屏
     * 不经过折叠态（折叠会退出横屏页），改用 悬停→展开→悬停 循环验证监听可重复触发
     * base(Stack)：两次都占满全屏，bottom 都 ≈ 屏底（远离半屏）→ FAIL
     * patch(FolderStack)：两次都约束到上半屏，bottom 都 ≈ 半屏 → PASS
     */
    it('hover_repeatableConstrain', Level.LEVEL3, async (done: Function) => {
      const screen = await driver.getDisplaySize();
      const halfHeight: number = screen.y / 2;
      const tolerance: number = screen.y * 0.15;
      // 第一次悬停：视频被约束
      await ensurePlaying(driver);
      const bounds1 = await (await driver.findComponent(ON.id('upperVideoPlayer'))).getBounds();
      const constrained1: boolean = Math.abs(bounds1.bottom - halfHeight) <= tolerance;
      // 切到展开态（不退出横屏页），再切回悬停态
      await triggerFold('open', 3000);
      await triggerLandscapeHover(driver);
      // 第二次悬停：视频仍被约束
      await ensurePlaying(driver);
      const bounds2 = await (await driver.findComponent(ON.id('upperVideoPlayer'))).getBounds();
      const constrained2: boolean = Math.abs(bounds2.bottom - halfHeight) <= tolerance;
      expect(constrained1 && constrained2).assertTrue();
      done();
    });
  });
}
