import { randomInt } from '@aztec/foundation/crypto';
import { Fr } from '@aztec/foundation/fields';
import { BufferReader } from '@aztec/foundation/serialize';
import { bufferToHex, hexToBuffer } from '@aztec/foundation/string';

import { schemas } from '../schemas/index.js';
import { Vector } from '../types/shared.js';

/**
 * The Note class represents a Note emitted from a Noir contract as a vector of Fr (finite field) elements.
 * This data also represents a preimage to a note hash.
 */
export class Note extends Vector<Fr> {
  toJSON() {
    return this.toBuffer();
  }

  static get schema() {
    return schemas.Buffer.transform(Note.fromBuffer);
  }

  /**
   * Create a Note instance from a Buffer or BufferReader.
   * The input 'buffer' can be either a Buffer containing the serialized Fr elements or a BufferReader instance.
   * This function reads the Fr elements in the buffer and constructs a Note with them.
   *
   * @param buffer - The Buffer or BufferReader containing the serialized Fr elements.
   * @returns A Note instance containing the deserialized Fr elements.
   */
  static fromBuffer(buffer: Buffer | BufferReader) {
    const reader = BufferReader.asReader(buffer);
    return new Note(reader.readVector(Fr));
  }

  /**
   * Generates a random Note instance with a variable number of items.
   * The number of items is determined by a random value between 1 and 10 (inclusive).
   * Each item in the Note is generated using the Fr.random() method.
   *
   * @returns A randomly generated Note instance.
   */
  static random() {
    const numItems = randomInt(10) + 1;
    const items = Array.from({ length: numItems }, () => Fr.random());
    return new Note(items);
  }

  /**
   * Returns a hex representation of the note.
   * @returns A hex string with the vector length as first element.
   */
  override toString() {
    return bufferToHex(this.toBuffer());
  }

  /**
   * Creates a new Note instance from a hex string.
   * @param str - Hex representation.
   * @returns A Note instance.
   */
  static fromString(str: string) {
    return Note.fromBuffer(hexToBuffer(str));
  }

  get length() {
    return this.items.length;
  }

  equals(other: Note) {
    return this.items.every((item, index) => item.equals(other.items[index]));
  }
}
