import type { AztecAddress, Wallet } from '@aztec/aztec.js';
import { StaticChildContract } from '@aztec/noir-test-contracts.js/StaticChild';
import { StaticParentContract } from '@aztec/noir-test-contracts.js/StaticParent';

import { STATIC_CALL_STATE_MODIFICATION_ERROR, STATIC_CONTEXT_ASSERTION_ERROR } from './fixtures/fixtures.js';
import { setup } from './fixtures/utils.js';

describe('e2e_static_calls', () => {
  let wallet: Wallet;
  let parentContract: StaticParentContract;
  let childContract: StaticChildContract;
  let teardown: () => Promise<void>;
  let owner: AztecAddress;
  let sender: AztecAddress;

  beforeAll(async () => {
    ({ teardown, wallet } = await setup());
    owner = wallet.getCompleteAddress().address;
    (sender = owner), (parentContract = await StaticParentContract.deploy(wallet).send().deployed());
    childContract = await StaticChildContract.deploy(wallet).send().deployed();

    // We create a note in the set, such that later reads doesn't fail due to get_notes returning 0 notes
    await childContract.methods.private_set_value(42n, owner, sender).send().wait();
  });

  afterAll(() => teardown());

  describe('direct view calls to child', () => {
    it('performs legal private static calls', async () => {
      await childContract.methods.private_get_value(42n, owner).send().wait();
    });

    it('fails when performing non-static calls to poorly written static private functions', async () => {
      await expect(childContract.methods.private_illegal_set_value(42n, owner).send().wait()).rejects.toThrow(
        STATIC_CALL_STATE_MODIFICATION_ERROR,
      );
    });

    it('performs legal public static calls', async () => {
      await childContract.methods.pub_get_value(42n).send().wait();
    });

    it('fails when performing non-static calls to poorly written static public functions', async () => {
      await expect(childContract.methods.pub_illegal_inc_value(42n).simulate()).rejects.toThrow(
        STATIC_CALL_STATE_MODIFICATION_ERROR,
      );
    });
  });

  describe('parent calls child', () => {
    it('performs legal private to private static calls', async () => {
      // Using low level calls
      await parentContract.methods
        .private_static_call(childContract.address, await childContract.methods.private_get_value.selector(), [
          42n,
          owner,
        ])
        .send()
        .wait();

      // Using the contract interface
      await parentContract.methods.private_get_value_from_child(childContract.address, 42n, owner).send().wait();
    });

    it('performs legal (nested) private to private static calls', async () => {
      await parentContract.methods
        .private_nested_static_call(childContract.address, await childContract.methods.private_get_value.selector(), [
          42n,
          owner,
        ])
        .send()
        .wait();
    });

    it('performs legal public to public static calls', async () => {
      // Using low level calls
      await parentContract.methods
        .public_static_call(childContract.address, await childContract.methods.pub_get_value.selector(), [42n])
        .send()
        .wait();

      // Using contract interface
      await parentContract.methods.public_get_value_from_child(childContract.address, 42n).send().wait();
    });

    it('performs legal (nested) public to public static calls', async () => {
      await parentContract.methods
        .public_nested_static_call(childContract.address, await childContract.methods.pub_get_value.selector(), [42n])
        .send()
        .wait();
    });

    it('performs legal enqueued public static calls', async () => {
      // Using low level calls
      await parentContract.methods
        .enqueue_static_call_to_pub_function(
          childContract.address,
          await childContract.methods.pub_get_value.selector(),
          [42n],
        )
        .send()
        .wait();

      // Using contract interface
      await parentContract.methods.enqueue_public_get_value_from_child(childContract.address, 42).send().wait();
    });

    it('performs legal (nested) enqueued public static calls', async () => {
      await parentContract.methods
        .enqueue_static_nested_call_to_pub_function(
          childContract.address,
          await childContract.methods.pub_get_value.selector(),
          [42n],
        )
        .send()
        .wait();
    });

    it('fails when performing illegal private to private static calls', async () => {
      await expect(
        parentContract.methods
          .private_static_call_3_args(childContract.address, await childContract.methods.private_set_value.selector(), [
            42n,
            owner,
            sender,
          ])
          .send()
          .wait(),
      ).rejects.toThrow(STATIC_CALL_STATE_MODIFICATION_ERROR);
    });

    it('fails when performing non-static calls to poorly written private static functions', async () => {
      await expect(
        parentContract.methods
          .private_call(childContract.address, await childContract.methods.private_illegal_set_value.selector(), [
            42n,
            owner,
          ])
          .send()
          .wait(),
      ).rejects.toThrow(STATIC_CONTEXT_ASSERTION_ERROR);
    });

    it('fails when performing illegal (nested) private to private static calls', async () => {
      await expect(
        parentContract.methods
          .private_nested_static_call_3_args(
            childContract.address,
            await childContract.methods.private_set_value.selector(),
            [42n, owner, sender],
          )
          .send()
          .wait(),
      ).rejects.toThrow(STATIC_CALL_STATE_MODIFICATION_ERROR);
    });

    it('fails when performing illegal public to public static calls', async () => {
      await expect(
        parentContract.methods
          .public_static_call(childContract.address, await childContract.methods.pub_set_value.selector(), [42n])
          .simulate(),
      ).rejects.toThrow(STATIC_CALL_STATE_MODIFICATION_ERROR);
    });

    it('fails when performing illegal (nested) public to public static calls', async () => {
      await expect(
        parentContract.methods
          .public_nested_static_call(childContract.address, await childContract.methods.pub_set_value.selector(), [42n])
          .simulate(),
      ).rejects.toThrow(STATIC_CALL_STATE_MODIFICATION_ERROR);
    });

    it('fails when performing illegal enqueued public static calls', async () => {
      await expect(
        parentContract.methods
          .enqueue_static_call_to_pub_function(
            childContract.address,
            await childContract.methods.pub_set_value.selector(),
            [42n],
          )
          .simulate(),
      ).rejects.toThrow(STATIC_CALL_STATE_MODIFICATION_ERROR);
    });

    it('fails when performing illegal (nested) enqueued public static calls', async () => {
      await expect(
        parentContract.methods
          .enqueue_static_nested_call_to_pub_function(
            childContract.address,
            await childContract.methods.pub_set_value.selector(),
            [42n],
          )
          .simulate(),
      ).rejects.toThrow(STATIC_CALL_STATE_MODIFICATION_ERROR);
    });

    it('fails when performing non-static enqueue calls to poorly written public static functions', async () => {
      await expect(
        parentContract.methods
          .enqueue_call(childContract.address, await childContract.methods.pub_illegal_inc_value.selector(), [
            42n,
            owner,
          ])
          .simulate(),
      ).rejects.toThrow(STATIC_CONTEXT_ASSERTION_ERROR);
    });
  });
});
