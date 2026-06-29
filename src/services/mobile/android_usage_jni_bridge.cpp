#include "services/mobile/mobile_usage_repository.h"

#ifdef Q_OS_ANDROID

#include <jni.h>

#include <QDateTime>
#include <QString>

namespace {

QString javaString(JNIEnv* env, jstring value) {
  if (value == nullptr) return QString();
  const char* chars = env->GetStringUTFChars(value, nullptr);
  const QString result = QString::fromUtf8(chars);
  env->ReleaseStringUTFChars(value, chars);
  return result;
}

jfieldID fieldId(JNIEnv* env, jclass clazz, const char* name,
                 const char* signature) {
  return env->GetFieldID(clazz, name, signature);
}

}  // namespace

extern "C" JNIEXPORT jboolean JNICALL
Java_com_timearc_mobile_usage_AndroidUsageNativeBridge_nativeSyncAggregatedUsage(
    JNIEnv* env,
    jclass,
    jobjectArray records,
    jlong beginMs,
    jlong endMs) {
  if (records == nullptr) return JNI_FALSE;

  const jsize count = env->GetArrayLength(records);
  if (count == 0) return JNI_TRUE;

  jobject first = env->GetObjectArrayElement(records, 0);
  jclass recordClass = env->GetObjectClass(first);
  const jfieldID packageField =
      fieldId(env, recordClass, "packageName", "Ljava/lang/String;");
  const jfieldID labelField =
      fieldId(env, recordClass, "appLabel", "Ljava/lang/String;");
  const jfieldID foregroundField =
      fieldId(env, recordClass, "totalTimeInForegroundMs", "J");
  const jfieldID sourceField =
      fieldId(env, recordClass, "source", "Ljava/lang/String;");
  env->DeleteLocalRef(first);

  const QDate localDate =
      QDateTime::fromMSecsSinceEpoch(beginMs).date();
  const qint64 beginSec = beginMs / 1000LL;
  const qint64 endSec = endMs / 1000LL;

  MobileUsageRepository repository;
  for (jsize i = 0; i < count; ++i) {
    jobject record = env->GetObjectArrayElement(records, i);
    const QString packageName = javaString(
        env, static_cast<jstring>(env->GetObjectField(record, packageField)));
    const QString appLabel = javaString(
        env, static_cast<jstring>(env->GetObjectField(record, labelField)));
    const QString source = javaString(
        env, static_cast<jstring>(env->GetObjectField(record, sourceField)));
    const jlong foregroundMs = env->GetLongField(record, foregroundField);
    const bool ok = repository.upsertDailyUsageSummary(
        QString(), packageName, appLabel, appLabel, localDate.toString(Qt::ISODate),
        beginSec, endSec, static_cast<int>(foregroundMs / 1000LL), source);
    env->DeleteLocalRef(record);
    if (!ok) return JNI_FALSE;
  }

  return JNI_TRUE;
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_timearc_mobile_usage_AndroidUsageNativeBridge_nativeSyncRecentSessions(
    JNIEnv* env,
    jclass,
    jobjectArray sessions,
    jlong,
    jlong) {
  if (sessions == nullptr) return JNI_FALSE;

  const jsize count = env->GetArrayLength(sessions);
  if (count == 0) return JNI_TRUE;

  jobject first = env->GetObjectArrayElement(sessions, 0);
  jclass sessionClass = env->GetObjectClass(first);
  const jfieldID packageField =
      fieldId(env, sessionClass, "packageName", "Ljava/lang/String;");
  const jfieldID labelField =
      fieldId(env, sessionClass, "appLabel", "Ljava/lang/String;");
  const jfieldID startField = fieldId(env, sessionClass, "startTimeMs", "J");
  const jfieldID endField = fieldId(env, sessionClass, "endTimeMs", "J");
  const jfieldID sourceField =
      fieldId(env, sessionClass, "source", "Ljava/lang/String;");
  env->DeleteLocalRef(first);

  MobileUsageRepository repository;
  for (jsize i = 0; i < count; ++i) {
    jobject session = env->GetObjectArrayElement(sessions, i);
    const QString packageName = javaString(
        env, static_cast<jstring>(env->GetObjectField(session, packageField)));
    const QString appLabel = javaString(
        env, static_cast<jstring>(env->GetObjectField(session, labelField)));
    const QString source = javaString(
        env, static_cast<jstring>(env->GetObjectField(session, sourceField)));
    const jlong startMs = env->GetLongField(session, startField);
    const jlong endMs = env->GetLongField(session, endField);
    const qint64 startSec = startMs / 1000LL;
    const qint64 endSec = endMs / 1000LL;
    if (endSec <= startSec) {
      env->DeleteLocalRef(session);
      continue;
    }
    const bool ok = repository.addUsageSession(
        QString(), packageName, appLabel, appLabel, startSec, endSec, source);
    env->DeleteLocalRef(session);
    if (!ok) return JNI_FALSE;
  }

  return JNI_TRUE;
}

#endif
