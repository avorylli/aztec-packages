import { omit } from '@aztec/foundation/collection';
import { type Logger, createLogger } from '@aztec/foundation/log';
import { retryUntil } from '@aztec/foundation/retry';

import { inspect } from 'util';
import {
  type Client,
  type Hex,
  type PublicClient,
  type TransactionSerializableEIP4844,
  keccak256,
  parseTransaction,
  publicActions,
  serializeTransaction,
  walletActions,
} from 'viem';

import { type ViemClient, isExtendedClient } from '../types.js';

export function waitUntilBlock<T extends Client>(client: T, blockNumber: number | bigint, logger?: Logger) {
  const publicClient =
    'getBlockNumber' in client && typeof client.getBlockNumber === 'function'
      ? (client as unknown as PublicClient)
      : client.extend(publicActions);

  return retryUntil(
    async () => {
      const currentBlockNumber = await publicClient.getBlockNumber({ cacheTime: 0 });
      logger?.debug(`Block number is ${currentBlockNumber} (waiting until ${blockNumber})`);
      return currentBlockNumber >= BigInt(blockNumber);
    },
    `Wait until L1 block ${blockNumber}`,
    120,
    0.1,
  );
}

export function waitUntilL1Timestamp<T extends Client>(client: T, timestamp: number | bigint, logger?: Logger) {
  const publicClient =
    'getBlockNumber' in client && typeof client.getBlockNumber === 'function'
      ? (client as unknown as PublicClient)
      : client.extend(publicActions);

  let lastBlock: bigint | undefined = undefined;
  return retryUntil(
    async () => {
      const currentBlockNumber = await publicClient.getBlockNumber({ cacheTime: 0 });
      if (currentBlockNumber === lastBlock) {
        return false;
      }
      lastBlock = currentBlockNumber;
      const currentBlock = await publicClient.getBlock({ includeTransactions: false, blockNumber: currentBlockNumber });
      const currentTs = currentBlock.timestamp;
      logger?.debug(`Block timstamp is ${currentTs} (waiting until ${timestamp})`);
      return currentTs >= BigInt(timestamp);
    },
    `Wait until L1 timestamp ${timestamp}`,
    120,
    0.1,
  );
}

export interface Delayer {
  /** Returns the hashes of all effectively sent txs. */
  getSentTxHashes(): Hex[];
  /** Returns the raw hex for all cancelled txs. */
  getCancelledTxs(): Hex[];
  /** Delays the next tx to be sent so it lands on the given L1 block number. */
  pauseNextTxUntilBlock(l1BlockNumber: number | bigint | undefined): void;
  /** Delays the next tx to be sent so it lands on the given timestamp. */
  pauseNextTxUntilTimestamp(l1Timestamp: number | bigint | undefined): void;
  /** Delays the next tx to be sent indefinitely. */
  cancelNextTx(): void;
}

class DelayerImpl implements Delayer {
  constructor(opts: { ethereumSlotDuration: bigint | number }) {
    this.ethereumSlotDuration = BigInt(opts.ethereumSlotDuration);
  }

  public ethereumSlotDuration: bigint;
  public nextWait: { l1Timestamp: bigint } | { l1BlockNumber: bigint } | { indefinitely: true } | undefined = undefined;
  public sentTxHashes: Hex[] = [];
  public cancelledTxs: Hex[] = [];

  getSentTxHashes() {
    return this.sentTxHashes;
  }

  getCancelledTxs(): Hex[] {
    return this.cancelledTxs;
  }

  pauseNextTxUntilBlock(l1BlockNumber: number | bigint) {
    this.nextWait = { l1BlockNumber: BigInt(l1BlockNumber) };
  }

  pauseNextTxUntilTimestamp(l1Timestamp: number | bigint) {
    this.nextWait = { l1Timestamp: BigInt(l1Timestamp) };
  }

  cancelNextTx() {
    this.nextWait = { indefinitely: true };
  }
}

/**
 * Returns a new client (without modifying the one passed in) with an injected tx delayer.
 * The delayer can be used to hold off the next tx to be sent until a given block number.
 * TODO(#10824): This doesn't play along well with blob txs for some reason.
 */
export function withDelayer<T extends ViemClient>(
  client: T,
  opts: { ethereumSlotDuration: bigint | number },
): { client: T; delayer: Delayer } {
  if (!isExtendedClient(client)) {
    throw new Error('withDelayer has to be instantiated with a wallet viem client.');
  }
  const logger = createLogger('ethereum:tx_delayer');
  const delayer = new DelayerImpl(opts);

  const extended = client
    // Tweak sendRawTransaction so it uses the delay defined in the delayer.
    // Note that this will only work with local accounts (ie accounts for which we have the private key).
    // Transactions signed by the node will not be delayed since they use sendTransaction directly,
    // but we do not use them in our codebase at all.
    .extend(client => ({
      async sendRawTransaction(...args) {
        if (delayer.nextWait !== undefined) {
          const waitUntil = delayer.nextWait;
          delayer.nextWait = undefined;

          // Compute the tx hash manually so we emulate sendRawTransaction response
          const { serializedTransaction } = args[0];
          const txHash = computeTxHash(serializedTransaction);

          // Cancel tx outright if instructed
          if ('indefinitely' in waitUntil && waitUntil.indefinitely) {
            logger.info(`Cancelling tx ${txHash}`);
            delayer.cancelledTxs.push(serializedTransaction);
            return Promise.resolve(txHash);
          }

          const publicClient = client as unknown as PublicClient;
          const wait =
            'l1BlockNumber' in waitUntil
              ? waitUntilBlock(publicClient, waitUntil.l1BlockNumber - 1n, logger)
              : 'l1Timestamp' in waitUntil
              ? waitUntilL1Timestamp(publicClient, waitUntil.l1Timestamp - delayer.ethereumSlotDuration, logger)
              : undefined;

          logger.info(`Delaying tx ${txHash} until ${inspect(waitUntil)}`, {
            argsLen: args.length,
            ...omit(parseTransaction(serializedTransaction), 'data', 'sidecars'),
          });

          // Do not await here so we can return the tx hash immediately as if it had been sent on the spot.
          // Instead, delay it so it lands on the desired block number or timestamp, assuming anvil will
          // mine it immediately.
          void wait!
            .then(async () => {
              const clientTxHash = await client.sendRawTransaction(...args);
              if (clientTxHash !== txHash) {
                logger.error(`Tx hash returned by the client does not match computed one`, {
                  clientTxHash,
                  computedTxHash: txHash,
                });
              }
              logger.info(`Sent previously delayed tx ${clientTxHash} to land on ${inspect(waitUntil)}`);
              delayer.sentTxHashes.push(clientTxHash);
            })
            .catch(err => logger.error(`Error sending tx after delay`, err));

          return Promise.resolve(txHash);
        } else {
          const txHash = await client.sendRawTransaction(...args);
          logger.verbose(`Sent tx immediately ${txHash}`);
          delayer.sentTxHashes.push(txHash);
          return txHash;
        }
      },
    }))
    // Re-extend with sendTransaction so it uses the modified sendRawTransaction.
    .extend(client => ({ sendTransaction: walletActions(client).sendTransaction }))
    // And with the actions that depend on the modified sendTransaction
    .extend(client => ({
      writeContract: walletActions(client).writeContract,
      deployContract: walletActions(client).deployContract,
    })) as T;

  return { client: extended, delayer };
}

/**
 * Compute the tx hash given the serialized tx. Note that if this is a blob tx, we need to
 * exclude the blobs, commitments, and proofs from the hash.
 */
function computeTxHash(serializedTransaction: Hex) {
  if (serializedTransaction.startsWith('0x03')) {
    const parsed = parseTransaction(serializedTransaction);
    if (parsed.blobs || parsed.sidecars) {
      // eslint-disable-next-line @typescript-eslint/no-unused-vars
      const { blobs, sidecars, ...rest } = parsed;
      return keccak256(serializeTransaction({ type: 'eip4844', ...rest } as TransactionSerializableEIP4844));
    }
  }
  return keccak256(serializedTransaction);
}
