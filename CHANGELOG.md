# Change Log

## TODO

- 框架的文档
- 自发的目标，不是总跟着鼠标走
- 角、有物理特性的装饰物
- 墙
- 定时不定时重刷一个，因为可能有bug把它搞坏
- 起飞和飞行的粒子效果
- 喷火/喷水
- 鼠标画法阵召唤食物什么的
- 蒙皮，自己画材质
- 像素化
- 调整大小

## Bilibili评论（不一定实现）

- geezmolycos:
  - 做出雨世界秃鹫
  - 做五卵石
  - 移植到wallpaper engine上
- 流水丶残花
  - 魔王鹫和钢秃鹫，秃鹫换皮肤
- 狂暴蹲饼大队长
  - 实现蛞蝓猫
- 希瓦洛白， 水永欢乐
  - 要东方龙
- 妩媚-WM
  - 要月姐
- _Geng-
  - 要拟态草
- 第三宇宙速度_
  - 要蜥蜴
- 久远の黄沙
  - 要偷吃桌面图标

## [1.2.0] - 2024-05-16

- 在菜单中添加调整各部位颜色，可以保存
- 调整龙的目标，让龙不会急迫转弯
- 腿迈步的时候给身体拖拽
- 可以使用鼠标把龙到处拖动
- 编写了 skeleton 的文档

## [1.1.0] - 2024-03-25

- 界面更改为Slab，不依赖动态库，支持其他操作系统
- ctrl+alt+右键唤出菜单，而不是固定位置出现菜单
- 菜单中增加了窗口属性、显示器等设置
- 保存读取用户配置
- 增加多级log系统，增加错误回报
- 可以独立出现在某个Windows虚拟桌面上，通过不隐藏任务栏图标实现(#2)
- port模块增加了一个虚拟实现，在不支持的系统上至少可以运行

## [1.0.0] - 2024-03-17

- 正式发布
- 龙的身体各部分基本功能正常，会跟随鼠标移动
- 实现Windows透明窗口，置底等
- 构建了 Windows x86-64 版
