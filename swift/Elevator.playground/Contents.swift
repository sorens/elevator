//: Elevator - noun: a vertical people and thing mover

import Cocoa
import PlaygroundSupport

enum Direction {
    case Up
    case Down
    case Idle
    case GoTo
}

enum State {
    case Active
    case Disabled
    case Idle
    case Override
}

enum RequestType {
    case Floor
    case Destination
}

struct Request {
    var direction: Direction = Direction.Idle
    var floor: Int = 1
    var type: RequestType
    var id: String
    
    init(direction: Direction, floor: Int, type: RequestType) {
        self.direction = direction
        self.floor = floor
        self.type = type
        id = UUID().uuidString.lowercased()
    }
    
    init(floor: Int) {
        self.direction = Direction.GoTo
        self.type = RequestType.Destination
        self.floor = floor
        id = UUID().uuidString.lowercased()
    }
    
    func description() -> String {
        return "<Request id: \(id) type: \(type), direction: \(direction), floor: \(floor)>"
    }
}

class Elevator {
    let velocity: Int = 1     // how many seconds to move 1 floor
    let maxWeight: Double
    let maxFloor: Int
    var id: String
    var state: State = State.Idle
    var weight: Double = 0
    var floor: Int = 1
    var direction: Direction = Direction.Idle
    let control: Control
    let dispatchQueue: DispatchQueue = DispatchQueue(label: "com.orens.elevator.elevator")
    
    init(maxWeight: Double, maxFloor: Int, control: Control) {
        id = UUID().uuidString.lowercased()
        self.maxWeight = maxWeight
        self.maxFloor = maxFloor
        self.control = control
        print(description())
    }
    
    func addWeight(weight: Double) -> Double {
        self.weight += weight
        return self.weight
    }
    
    func removeWeight(weight: Double) -> Double {
        self.weight -= weight
        return self.weight
    }
    
    func description() -> String {
        return "<Elevator id: \(id), floor: \(floor), direction: \(direction), state: \(state), weight (max): \(weight) (\(maxWeight)), velocity: \(velocity)>"
    }
    
    func makeIdle() {
        self.state = State.Idle
    }
    
    func makeActive() {
        self.state = State.Active
    }
    
    func makeDisabled() {
        self.state = State.Disabled
    }
    
    func makeOverride() {
        self.state = State.Override
    }
    
    func open() {
        print("elevator: \(id) opening doors at floor: \(floor)")
    }
    
    func close() {
        print("elevator: \(id) closing doors at floor: \(floor)")
   }
    
    func arriveAtFloor() {
        open()
        sleep(2)
        close()
    }
    
    func move(direction: Direction) {
        if (direction != Direction.Idle) {
            self.direction = direction
            
            // travel time...
            sleep(UInt32(velocity))

            // move the elevator
            if (self.direction == Direction.Up) {
                floor += 1
            }
            else if (self.direction == Direction.Down) {
                floor -= 1
            }
            
            print("elevator: \(id) moving to floor: \(floor) ...")
        }
    }
};

class Control {
    var id: String
    var elevators = [String: Elevator]()
    var requests = [Request]()
    let dispatchQueue: DispatchQueue = DispatchQueue(label: "com.orens.elevator.control")
    
    init() {
        id = UUID().uuidString.lowercased()
    }
    
    func attachElevator(elevator: Elevator) {
        elevators[elevator.id] = elevator
    }
    
    func detachElevator(elevator: Elevator) {
        elevators.removeValue(forKey: elevator.id)
    }
    
    func description() -> String {
        return "<Control id: \(id) number_elevators: \(elevators.count)>"
    }
    
    func callElevator(request: Request) {
        requests.append(request)
        print("queue request for: \(request.description())")
    }
    
    private func _internalCallBestElevator(direction: Direction, floor: Int) -> Elevator {
        // TODO send it the first elevator for now
        return (elevators.first?.value)!
    }
    
    private func _internalProcessRequest() {
        if (!requests.isEmpty) {
            let next = requests.first
            requests.removeFirst()
            let elevator = _internalCallBestElevator(direction: (next?.direction)!, floor: (next?.floor)!)
            elevator.makeActive()
            var direction = Direction.Up
            if (elevator.floor > (next?.floor)!) {
                direction = Direction.Down
            }
            
            var open = false
            while (elevator.floor != next?.floor) {
                // move the elevator
                elevator.move(direction: direction)

                // then determine if we should open for this floor
                var remove = [Int]()
                for (index, value) in requests.enumerated() {
                    if (value.floor == elevator.floor && value.direction == direction) {
                        remove.append(index)
                        open = true
                    }
                }
                
                for r in remove {
                    requests.remove(at: r)
                }

                if (elevator.floor == next?.floor) {
                    open = true
                }
                
                if (open) {
                    elevator.arriveAtFloor()
                    open = false
                }
            }
            
            if (requests.isEmpty) {
                elevator.makeIdle()
            }
        }
    }
    
    func process() {
        PlaygroundPage.current.needsIndefiniteExecution = true
        dispatchQueue.async {
            var process = true
            while(process) {
                self._internalProcessRequest()
                
                // TODO this is only so that the Playground doesn't run forever
                if (self.requests.isEmpty) {
                    print("elevator control done processing")
                    process = false
                    PlaygroundPage.current.finishExecution()
                }
            }
        }
    }
}

class Building {
    var floors: Int
    let control: Control = Control()
    var elevators = [Elevator]()

    init(floors: Int) {
        self.floors = floors
        print(description())
        elevators.append(Elevator(maxWeight: 1200, maxFloor: self.floors, control: self.control))
        for elevator in elevators {
            control.attachElevator(elevator: elevator)
        }
        
        print(control.description())
        control.process()
    }
    
    func run() {
        control.callElevator(request: Request(direction: Direction.Up, floor: 3, type: RequestType.Floor))
        control.callElevator(request: Request(floor: 4))
        control.callElevator(request: Request(direction: Direction.Down, floor: 8, type: RequestType.Floor))
        control.callElevator(request: Request(floor: 2))
        control.callElevator(request: Request(direction: Direction.Up, floor: 1, type: RequestType.Floor))        
        control.callElevator(request: Request(direction: Direction.Down, floor: 5, type: RequestType.Floor))
        control.callElevator(request: Request(direction: Direction.Up, floor: 5, type: RequestType.Floor))
        control.callElevator(request: Request(floor: 1))
        control.callElevator(request: Request(floor: 9))
        control.callElevator(request: Request(direction: Direction.Down, floor: 10, type: RequestType.Floor))
        control.callElevator(request: Request(floor: 1))
        sleep(20)
        control.callElevator(request: Request(direction: Direction.Down, floor: 3, type: RequestType.Floor))
    }
    
    func description() -> String {
        return "<Building floors: \(floors)>"
    }
}

Building(floors: 10).run()
