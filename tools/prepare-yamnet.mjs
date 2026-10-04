// Expose the shipped classifier's pre-classifier mean embedding. No training,
// conversion, operator, weight or quantization changes are made.
import {readFileSync,writeFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const source=readFileSync(process.argv[2]);
if(createHash('sha256').update(source).digest('hex')!=='10c95ea3eb9a7bb4cb8bddf6feb023250381008177ac162ce169694d05c317de')throw Error('Unexpected source artifact');
const field=(t,n)=>{const v=t-source.readInt32LE(t);return t+source.readUInt16LE(v+4+n*2);};
const ref=p=>p+source.readUInt32LE(p);
const model=source.readUInt32LE(0),graphs=ref(field(model,2)),graph=ref(graphs+4);
const outputField=field(graph,2),offset=(source.length+3)&~3;
const result=Buffer.alloc(offset+12);source.copy(result);
result.writeUInt32LE(offset-outputField,outputField);
result.writeUInt32LE(2,offset);result.writeInt32LE(120,offset+4);result.writeInt32LE(115,offset+8);
writeFileSync(process.argv[3],result);
console.log(createHash('sha256').update(result).digest('hex'));
