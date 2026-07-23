#ifndef MOBILEUSAGEINSIGHTENGINE_H
#define MOBILEUSAGEINSIGHTENGINE_H

#include <QDate>
#include <QVariantList>
#include <QVariantMap>

class MobileUsageInsightEngine {
 public:
  static QVariantMap buildMonthlyReport(const QDate& month,
                                        const QVariantList& dailyRows,
                                        const QVariantList& sessions,
                                        const QVariantList& previousRows);
};

#include "mobile_usage_insight_engine.inc"

#endif
