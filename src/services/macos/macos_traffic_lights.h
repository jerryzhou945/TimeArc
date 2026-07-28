// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

#include <QObject>
#include <QPointer>

class QWindow;

class MacTrafficLightsController final : public QObject {
  Q_OBJECT

 public:
  explicit MacTrafficLightsController(QObject* parent = nullptr);
  ~MacTrafficLightsController() override;

  void attach(QWindow* window);
  Q_INVOKABLE void setVisible(bool visible);

 private:
  void createNativeViews();
  void destroyNativeViews();
  void updateWindowState();

  QPointer<QWindow> window_;
  void* nativeWindow_ = nullptr;
  void* closeButton_ = nullptr;
  void* minimizeButton_ = nullptr;
  void* zoomButton_ = nullptr;
  bool visible_ = true;
};
