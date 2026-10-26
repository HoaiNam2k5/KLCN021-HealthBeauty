import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import ts from 'typescript'

const source = await readFile(new URL('../src/features/appointments/appointmentStatus.ts', import.meta.url), 'utf8')
const { outputText } = ts.transpileModule(source, { compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.ES2022 } })
const { getAppointmentPrimaryAction, getAllowedNextAppointmentStatuses } = await import(`data:text/javascript;base64,${Buffer.from(outputText).toString('base64')}`)

test('primary actions follow confirm, start and complete without mandatory check-in', () => {
  assert.deepEqual(getAppointmentPrimaryAction('ChoXacNhan'), { status: 'DaXacNhan', label: 'Xác nhận lịch' })
  for (const state of ['DaXacNhan', 'DaDen']) assert.equal(getAppointmentPrimaryAction(state).status, 'DangThucHien')
  assert.equal(getAppointmentPrimaryAction('DangThucHien').status, 'HoanThanh')
  assert.ok(getAllowedNextAppointmentStatuses('DaXacNhan').includes('DaDen'))
  assert.ok(getAllowedNextAppointmentStatuses('DaXacNhan').includes('DangThucHien'))
})

test('terminal states have no write action and service in progress cannot be cancelled', () => {
  for (const state of ['HoanThanh', 'DaHuy', 'unknown']) assert.equal(getAppointmentPrimaryAction(state), null)
  assert.deepEqual(getAllowedNextAppointmentStatuses('DangThucHien'), ['HoanThanh'])
  assert.ok(!getAllowedNextAppointmentStatuses('DaXacNhan').includes('HoanThanh'))
})
