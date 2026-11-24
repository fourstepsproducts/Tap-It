/**
 * migrateFromAppwriteSql.js
 *
 * Imports the Appwrite migration dataset into MongoDB with full idempotency,
 * zero loss of original fields/metadata, native collection handling,
 * pre-write validation across all 12 collections, and strict conflict detection.
 *
 * Usage:
 *   node migrateFromAppwriteSql.js --dry-run
 *   node migrateFromAppwriteSql.js --confirm-import
 */

const fs = require('fs');
const path = require('path');
const mongoose = require('mongoose');
const dotenv = require('dotenv');

// Load environment configuration
dotenv.config();

const datasetPath = path.resolve(__dirname, '../migration/appwrite-migration-data.json');

const EXPECTED_COUNTS = {
  users: 57,
  categories: 52,
  items: 63,
  ledger_transactions: 17,
  profiles: 44,
  transactions: 34,
  investments: 0,
  notifications: 28,
  dutch_groups: 1,
  dutch_expenses: 3,
  dutch_settlements: 0,
  goals: 15,
};

// Target MongoDB collection mapping
const COLLECTION_MAPPING = {
  users: 'users',
  categories: 'categories',
  items: 'items',
  ledger_transactions: 'ledger_transactions',
  profiles: 'profiles',
  transactions: 'transactions',
  investments: 'investments',
  notifications: 'notifications',
  dutch_groups: 'dutch_groups',
  dutch_expenses: 'dutch_expenses',
  dutch_settlements: 'dutch_settlements',
  goals: 'goals',
};

/**
 * Deep equality comparison between two documents to determine if an existing
 * record is identical (skip) or conflicting.
 */
function areDocumentsEqual(docA, docB) {
  const keysToCompare = Object.keys(docA).filter((k) => k !== '_id');
  for (const k of keysToCompare) {
    const valA = docA[k];
    const valB = docB[k];

    // Normalize null / undefined
    if ((valA === null || valA === undefined) && (valB === null || valB === undefined)) {
      continue;
    }

    // Date comparison
    if (valA instanceof Date || valB instanceof Date) {
      const timeA = new Date(valA).getTime();
      const timeB = new Date(valB).getTime();
      if (timeA !== timeB) return false;
      continue;
    }

    // JSON objects / arrays
    if (typeof valA === 'object' && typeof valB === 'object' && valA !== null && valB !== null) {
      if (JSON.stringify(valA) !== JSON.stringify(valB)) {
        return false;
      }
      continue;
    }

    if (String(valA) !== String(valB)) {
      return false;
    }
  }
  return true;
}

/**
 * Transforms an exported JSON record into a MongoDB native document,
 * parsing ISO strings to native Date objects with exact milliseconds preserved,
 * and maintaining all original fields, permissions, and encrypted envelopes.
 */
function prepareDocumentForMongo(record) {
  const doc = { ...record };

  // Parse ISO timestamps to native Date objects without losing milliseconds
  const dateFields = [
    'createdAt', 'updatedAt', '$createdAt', '$updatedAt',
    'dateTime', 'targetDate', 'completedAt', 'scheduledDate',
    'lastUpdated', 'passwordUpdate', 'registration', 'accessedAt'
  ];

  for (const field of dateFields) {
    if (doc[field] && typeof doc[field] === 'string') {
      const d = new Date(doc[field]);
      if (!isNaN(d.getTime())) {
        doc[field] = d;
      }
    }
  }

  // Ensure string _id is primary key
  doc._id = String(doc._id || doc.$id);

  return doc;
}

async function run() {
  const isDryRun = process.argv.includes('--dry-run');
  const isConfirmImport = process.argv.includes('--confirm-import');

  if (!isDryRun && !isConfirmImport) {
    console.error('ERROR: You must specify either --dry-run or --confirm-import');
    console.log('Usage:');
    console.log('  node migrateFromAppwriteSql.js --dry-run');
    console.log('  node migrateFromAppwriteSql.js --confirm-import');
    process.exit(1);
  }

  console.log('====================================================');
  console.log(` MIGRATION EXECUTION MODE: ${isDryRun ? 'DRY-RUN (READ-ONLY)' : 'ACTUAL IMPORT'}`);
  console.log('====================================================\n');

  // 1. Validate Dataset File
  if (!fs.existsSync(datasetPath)) {
    console.error(`FATAL: Dataset not found at: ${datasetPath}`);
    process.exit(1);
  }

  console.log(`[1/5] Loading dataset: ${datasetPath}`);
  const rawData = fs.readFileSync(datasetPath, 'utf-8');
  const parsed = JSON.parse(rawData);
  const data = parsed.data || {};
  const metadata = parsed.metadata || {};

  console.log(`  Source: ${metadata.source || 'Appwrite backup'}`);
  console.log(`  Extracted At: ${metadata.extractedAt || 'N/A'}`);
  console.log(`  Timezone: ${metadata.timezoneInterpretation || 'UTC'}\n`);

  // 2. Validate Entities & Structure
  console.log('[2/5] Validating entity counts and record integrity...');
  let totalRecords = 0;
  let validationErrors = 0;

  for (const [entity, expectedCount] of Object.entries(EXPECTED_COUNTS)) {
    const list = data[entity] || [];
    totalRecords += list.length;
    const countOk = list.length === expectedCount;

    // Check duplicate IDs
    const ids = list.map((item) => String(item._id || item.$id));
    const uniqueIds = new Set(ids);
    const hasDuplicates = ids.length !== uniqueIds.size;

    if (!countOk) {
      console.error(`  [X] ${entity}: Count mismatch! Expected ${expectedCount}, got ${list.length}`);
      validationErrors++;
    } else if (hasDuplicates) {
      console.error(`  [X] ${entity}: Duplicate primary IDs detected!`);
      validationErrors++;
    } else {
      console.log(`  [OK] ${entity.padEnd(20)}: ${String(list.length).padStart(3)} records (0 duplicate IDs)`);
    }
  }

  if (validationErrors > 0) {
    console.error(`\nValidation failed with ${validationErrors} errors. Aborting.`);
    process.exit(1);
  }

  console.log(`\n  Total Verified Records: ${totalRecords} (Expected: 314)\n`);

  // 3. Connect to MongoDB for conflict / existence check
  const mongoUri = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/tapit_db';
  console.log(`[3/5] Connecting to MongoDB: ${mongoUri.replace(/:([^:@]+)@/, ':****@')}`);

  let mongoConnected = false;
  try {
    await mongoose.connect(mongoUri, { serverSelectionTimeoutMS: 3000 });
    mongoConnected = true;
    console.log('  MongoDB connection established.\n');
  } catch (err) {
    if (isDryRun) {
      console.log('  [NOTICE] MongoDB is not currently reachable.');
      console.log('  Proceeding with in-memory dry-run validation (0 writes guaranteed).\n');
    } else {
      console.error('  FATAL: Could not connect to MongoDB for actual import:', err.message);
      process.exit(1);
    }
  }

  // 4. Pre-write Validation & Conflict Detection Across ALL 12 Collections
  console.log('[4/5] Pre-evaluating operations & conflicts across ALL collections before any writes:');

  const summary = {};
  const toInsertMap = {}; // collectionName -> Array of documents to insert
  let totalToInsert = 0;
  let totalToSkip = 0;
  let totalConflicts = 0;

  const db = mongoConnected ? mongoose.connection.db : null;

  for (const [entity, list] of Object.entries(data)) {
    const collectionName = COLLECTION_MAPPING[entity];
    summary[entity] = { insert: 0, skip: 0, conflict: 0 };
    toInsertMap[collectionName] = [];

    if (!collectionName || list.length === 0) {
      continue;
    }

    const coll = db ? db.collection(collectionName) : null;

    for (const rawRecord of list) {
      const doc = prepareDocumentForMongo(rawRecord);

      if (coll) {
        // Query existing document using native driver
        const existing = await coll.findOne({ _id: doc._id });

        if (!existing) {
          summary[entity].insert++;
          totalToInsert++;
          toInsertMap[collectionName].push(doc);
        } else {
          // Check for conflicts
          if (areDocumentsEqual(doc, existing)) {
            summary[entity].skip++;
            totalToSkip++;
          } else {
            summary[entity].conflict++;
            totalConflicts++;
            console.error(`  CONFLICT in ${collectionName}: Record ${doc._id} differs from existing document!`);
          }
        }
      } else {
        // In-memory simulation when DB is offline during dry-run
        summary[entity].insert++;
        totalToInsert++;
        toInsertMap[collectionName].push(doc);
      }
    }

    console.log(
      `  - ${entity.padEnd(20)}: ${summary[entity].insert} to insert, ${summary[entity].skip} to skip, ${summary[entity].conflict} conflicts`
    );
  }

  console.log('\n====================================================');
  console.log(' PRE-WRITE EVALUATION SUMMARY');
  console.log('====================================================');
  console.log(`  Total Evaluated Records: ${totalRecords}`);
  console.log(`  Planned Inserts        : ${totalToInsert}`);
  console.log(`  Identical (To Skip)    : ${totalToSkip}`);
  console.log(`  Data Conflicts Detected: ${totalConflicts}`);
  console.log(`  Execution Mode         : ${isDryRun ? 'DRY-RUN (READ-ONLY)' : 'ACTUAL IMPORT'}`);
  console.log('====================================================\n');

  // Hard stop on any detected conflict
  if (totalConflicts > 0) {
    console.error(`FATAL: ${totalConflicts} conflict(s) detected. Aborting before any write operations.`);
    if (mongoConnected) await mongoose.disconnect();
    process.exit(1);
  }

  // 5. Execution or Dry-run conclusion
  if (isDryRun) {
    console.log('[5/5] DRY-RUN VERIFIED: 0 database writes made (GUARANTEED).');
    if (mongoConnected) {
      await mongoose.disconnect();
      console.log('MongoDB connection closed cleanly.');
    }
    return;
  }

  // Actual Import Mode (--confirm-import)
  console.log('[5/5] Executing actual import into MongoDB...');

  let insertedCount = 0;
  const partiallyInserted = {};

  try {
    for (const [entity, collectionName] of Object.entries(COLLECTION_MAPPING)) {
      const docsToInsert = toInsertMap[collectionName] || [];
      if (docsToInsert.length === 0) {
        continue;
      }

      const coll = db.collection(collectionName);
      // Native batch insert with ordered: true (aborts on first failure)
      const result = await coll.insertMany(docsToInsert, { ordered: true });
      const count = result.insertedCount || Object.keys(result.insertedIds || {}).length;
      insertedCount += count;
      partiallyInserted[collectionName] = count;
      console.log(`  [SAVED] ${collectionName.padEnd(20)}: Successfully inserted ${count} document(s).`);
    }

    console.log('\n====================================================');
    console.log(' IMPORT COMPLETE');
    console.log('====================================================');
    console.log(`  Total Documents Inserted : ${insertedCount}`);
    console.log(`  Skipped (Already Existed): ${totalToSkip}`);
    console.log('====================================================\n');
  } catch (err) {
    console.error('\nFATAL ERROR DURING BATCH INSERTION:', err.message);
    console.error('PARTIAL INSERTION REPORT (No transaction rollback occurred):');
    for (const [cName, cCount] of Object.entries(partiallyInserted)) {
      console.error(`  - ${cName}: ${cCount} records were inserted prior to failure.`);
    }
    console.error('The database may be in a partial state. Resolve the error before retrying.');
    if (mongoConnected) await mongoose.disconnect();
    process.exit(1);
  }

  if (mongoConnected) {
    await mongoose.disconnect();
    console.log('MongoDB connection closed cleanly.');
  }
}

run().catch((err) => {
  console.error('Unexpected migration execution error:', err);
  process.exit(1);
});
