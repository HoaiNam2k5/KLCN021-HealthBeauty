import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import * as api from '../../api/workSchedules'
import type { WorkScheduleRequest } from '../../types/workSchedules'

export const scheduleKeys = { all: ['work-schedules'] as const, staff: ['work-schedule-staff'] as const }

export function useWorkSchedules(filters: { staffId?: number; from: string; to: string }) {
  return useQuery({ queryKey: [...scheduleKeys.all, filters], queryFn: () => api.getWorkSchedules(filters) })
}

export function useScheduleStaff() {
  return useQuery({ queryKey: scheduleKeys.staff, queryFn: api.getScheduleStaff })
}

export function useSaveWorkSchedule() {
  const client = useQueryClient()
  return useMutation({
    mutationFn: (input: { id?: number; body: WorkScheduleRequest }) => input.id === undefined ? api.createWorkSchedule(input.body) : api.updateWorkSchedule(input.id, input.body),
    onSuccess: () => client.invalidateQueries({ queryKey: scheduleKeys.all }),
  })
}

export function useDeleteWorkSchedule() {
  const client = useQueryClient()
  return useMutation({ mutationFn: api.deleteWorkSchedule, onSuccess: () => client.invalidateQueries({ queryKey: scheduleKeys.all }) })
}
