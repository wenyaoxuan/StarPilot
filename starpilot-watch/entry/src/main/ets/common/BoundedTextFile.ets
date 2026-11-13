import { fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';

export function readBoundedText(path: string, limit: number): string {
  const size: number = fileIo.statSync(path).size;
  if (size <= 0 || size > limit) {
    throw new Error('文件为空或超过大小限制');
  }
  const text: string = fileIo.readTextSync(path, { length: limit + 1 });
  if (new util.TextEncoder().encodeInto(text).byteLength > limit) {
    throw new Error('文件超过大小限制');
  }
  return text;
}

export function writeAtomicText(path: string, text: string, limit: number): void {
  const bytes: Uint8Array = new util.TextEncoder().encodeInto(text);
  if (bytes.byteLength > limit) {
    throw new Error('文件超过大小限制');
  }
  const temp: string = path + '.tmp';
  const file: fileIo.File = fileIo.openSync(temp, fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE |
    fileIo.OpenMode.TRUNC);
  try {
    if (fileIo.writeSync(file.fd, bytes.buffer) !== bytes.byteLength) {
      throw new Error('文件写入不完整');
    }
    fileIo.fsyncSync(file.fd);
  } finally {
    fileIo.closeSync(file);
  }
  fileIo.renameSync(temp, path);
}
