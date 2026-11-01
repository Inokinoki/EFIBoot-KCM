/**
 * SPDX-FileCopyrightText: 2026
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

#include <QtTest/QtTest>

#include <QCoreApplication>
#include <QDir>
#include <QStandardPaths>

#include <qefi.h>

#include "efibootentrymodel.h"
#include "efibootmanager.h"

#include "test_data.h"

using namespace Qt::StringLiterals;

static const QUuid globalGuid = QUuid(QStringLiteral("8be4df61-93ca-11d2-aa0d-00e098032b8c"));

static QByteArray bootOptionOne()
{
    return QByteArray(reinterpret_cast<const char *>(test_boot_data), TEST_BOOT_DATA_LENGTH);
}

static QByteArray bootOptionTwo()
{
    return QByteArray(reinterpret_cast<const char *>(test_boot_data2), TEST_BOOT_DATA2_LENGTH);
}

static QByteArray uint16Array(std::initializer_list<quint16> values)
{
    QByteArray data;
    for (const quint16 value : values) {
        const quint16 le = qToLittleEndian<quint16>(value);
        data.append(reinterpret_cast<const char *>(&le), sizeof(le));
    }
    return data;
}

static QString variableStorePath()
{
    return QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
}

static void clearVariableStore()
{
    QDir store(variableStorePath());
    if (store.exists()) {
        store.removeRecursively();
    }
}

class TestEfiBootManager : public QObject
{
    Q_OBJECT
private Q_SLOTS:
    void initTestCase();
    void cleanupTestCase();
    void init();

    void testEmptyStoreReportsError();
    void testReadsEntriesFromBootOrder();
    void testMarksFirstBootOrderEntryAsDefault();
    void testMarksBootNext();
    void testMarksBootCurrent();
    void testSelectsIconByNameAndPath();
    void testDetailsForEntry();
};

void TestEfiBootManager::initTestCase()
{
    // Keep the dummy backend away from the real user data directory.
    QStandardPaths::setTestModeEnabled(true);
    QCoreApplication::setOrganizationName(QStringLiteral("KDE"));
    QCoreApplication::setApplicationName(QStringLiteral("efibootkcm-test"));

    // The dummy backend only creates the last path element, so the parents
    // have to exist before the first variable is written.
    QDir().mkpath(variableStorePath());
}

void TestEfiBootManager::cleanupTestCase()
{
    clearVariableStore();
}

void TestEfiBootManager::init()
{
    clearVariableStore();
}

void TestEfiBootManager::testEmptyStoreReportsError()
{
    EfiBootManager manager;
    manager.refresh();

    QCOMPARE(manager.entries()->rowCount(), 0);
    QVERIFY(!manager.lastError().isEmpty());
}

void TestEfiBootManager::testReadsEntriesFromBootOrder()
{
    qefi_set_variable(globalGuid, QStringLiteral("BootOrder"), uint16Array({0x0002, 0x0001}));
    qefi_set_variable(globalGuid, QStringLiteral("Boot0001"), bootOptionOne());
    qefi_set_variable(globalGuid, QStringLiteral("Boot0002"), bootOptionTwo());

    EfiBootManager manager;
    manager.refresh();

    QCOMPARE(manager.available(), true);
    QCOMPARE(manager.lastError(), QString());
    QCOMPARE(manager.entries()->rowCount(), 2);

    const auto *one = manager.entries()->entryForId(0x0001);
    QVERIFY(one);
    QCOMPARE(one->name, QString::fromLatin1(test_boot_name));
    QCOMPARE(one->path, QString::fromLatin1(test_boot_path));

    const auto *two = manager.entries()->entryForId(0x0002);
    QVERIFY(two);
    QCOMPARE(two->name, QString::fromLatin1(test_boot_name2));
    QCOMPARE(two->path, QString::fromLatin1(test_boot_path2));
}

void TestEfiBootManager::testMarksFirstBootOrderEntryAsDefault()
{
    qefi_set_variable(globalGuid, QStringLiteral("BootOrder"), uint16Array({0x0002, 0x0001}));
    qefi_set_variable(globalGuid, QStringLiteral("Boot0001"), bootOptionOne());
    qefi_set_variable(globalGuid, QStringLiteral("Boot0002"), bootOptionTwo());

    EfiBootManager manager;
    manager.refresh();

    // The default entry is the first one in BootOrder, not the lowest ID.
    const auto *one = manager.entries()->entryForId(0x0001);
    const auto *two = manager.entries()->entryForId(0x0002);
    QVERIFY(one && two);
    QCOMPARE(one->isDefault, false);
    QCOMPARE(two->isDefault, true);
}

void TestEfiBootManager::testMarksBootNext()
{
    qefi_set_variable(globalGuid, QStringLiteral("BootOrder"), uint16Array({0x0002, 0x0001}));
    qefi_set_variable(globalGuid, QStringLiteral("Boot0001"), bootOptionOne());
    qefi_set_variable(globalGuid, QStringLiteral("Boot0002"), bootOptionTwo());
    qefi_set_variable(globalGuid, QStringLiteral("BootNext"), uint16Array({0x0001}));

    EfiBootManager manager;
    manager.refresh();

    const auto *one = manager.entries()->entryForId(0x0001);
    const auto *two = manager.entries()->entryForId(0x0002);
    QVERIFY(one && two);
    QCOMPARE(one->isBootNext, true);
    QCOMPARE(two->isBootNext, false);
}

void TestEfiBootManager::testMarksBootCurrent()
{
    qefi_set_variable(globalGuid, QStringLiteral("BootOrder"), uint16Array({0x0002, 0x0001}));
    qefi_set_variable(globalGuid, QStringLiteral("Boot0001"), bootOptionOne());
    qefi_set_variable(globalGuid, QStringLiteral("Boot0002"), bootOptionTwo());
    qefi_set_variable(globalGuid, QStringLiteral("BootCurrent"), uint16Array({0x0002}));

    EfiBootManager manager;
    manager.refresh();

    const auto *one = manager.entries()->entryForId(0x0001);
    const auto *two = manager.entries()->entryForId(0x0002);
    QVERIFY(one && two);
    QCOMPARE(one->isCurrent, false);
    QCOMPARE(two->isCurrent, true);
}

void TestEfiBootManager::testSelectsIconByNameAndPath()
{
    qefi_set_variable(globalGuid, QStringLiteral("BootOrder"), uint16Array({0x0002, 0x0001}));
    qefi_set_variable(globalGuid, QStringLiteral("Boot0001"), bootOptionOne());
    qefi_set_variable(globalGuid, QStringLiteral("Boot0002"), bootOptionTwo());

    EfiBootManager manager;
    manager.refresh();

    auto *model = manager.entries();

    // The entries are sorted by ID, so row 0 is Boot0001 and row 1 is Boot0002.
    QCOMPARE(model->data(model->index(0, 0), EfiBootEntryModel::IconNameRole).toString(), QStringLiteral("drive-harddisk"));
    QCOMPARE(model->data(model->index(1, 0), EfiBootEntryModel::IconNameRole).toString(), QStringLiteral("image-x-ico"));
}

void TestEfiBootManager::testDetailsForEntry()
{
    qefi_set_variable(globalGuid, QStringLiteral("BootOrder"), uint16Array({0x0001}));
    qefi_set_variable(globalGuid, QStringLiteral("Boot0001"), bootOptionOne());

    EfiBootManager manager;
    manager.refresh();

    const QVariantMap details = manager.detailsForEntry(0x0001);
    QCOMPARE(details.value(QStringLiteral("entryId")).toInt(), 1);
    QCOMPARE(details.value(QStringLiteral("entryIdHex")).toString(), QStringLiteral("0001"));
    QCOMPARE(details.value(QStringLiteral("name")).toString(), QString::fromLatin1(test_boot_name));
    QCOMPARE(details.value(QStringLiteral("path")).toString(), QString::fromLatin1(test_boot_path));
    QCOMPARE(details.value(QStringLiteral("rawSize")).toInt(), TEST_BOOT_DATA_LENGTH);
    QVERIFY(!details.value(QStringLiteral("rawHex")).toString().isEmpty());
}

QTEST_MAIN(TestEfiBootManager)

#include "test_efibootmanager.moc"
