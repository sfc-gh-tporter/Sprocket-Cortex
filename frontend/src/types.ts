export interface Bike {
  bike_id: number
  year: number
  brand: string
  model: string
  bike_type: string
  display_name: string
}

export interface Component {
  component_id: number
  category: string
  brand: string
  model: string
}

export interface MaintenanceItem {
  task_id: number
  task_name: string
  component_name: string
  interval_description: string
  due_label: string
  status: 'overdue' | 'upcoming' | 'done'
}

export interface ChatMessage {
  id: string
  role: 'user' | 'assistant'
  content: string
  sources?: string[]
  streaming?: boolean
}
