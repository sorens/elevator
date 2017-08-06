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

class Object {
    var id: String
    var name: String
    
    init(name: String) {
        id = UUID().uuidString.lowercased()
        self.name = name
    }
    
    convenience init() {
        self.init(name: "OBJ")
    }
    
    func short_id() -> String {
        return id.substring(to: id.index(id.startIndex, offsetBy: 8))
    }

    func debug(message: String) {
        print("\(self.name) {\(short_id())} | \(message)")
    }
    
}

class Request : Object {
    var direction: Direction = Direction.Idle
    var floor: Int = 1
    var type: RequestType
    var destinationAction: ((_ original: Request) -> ())?
    var original: Request?
    
    init(direction: Direction, floor: Int, type: RequestType, block: @escaping (_ original: Request) -> ()) {
        self.direction = direction
        self.floor = floor
        self.type = type
        self.destinationAction = block
        super.init(name: "RQS")
    }
    
    init(floor: Int, original: Request?) {
        self.direction = Direction.GoTo
        self.type = RequestType.Destination
        self.floor = floor
        self.original = original
        super.init(name: "RQS")
    }
    
    func description() -> String {
        return "<Request id: \(short_id()) type: \(type), direction: \(direction), floor: \(floor), original: \(original?.short_id())>"
    }
}

class Elevator : Object {
    let velocity: Int = 1     // how many seconds to move 1 floor
    let maxWeight: Double
    let maxFloor: Int
    var state: State = State.Idle
    var weight: Double = 0
    var floor: Int = 1
    var direction: Direction = Direction.Idle
    let control: Control
    let dispatchQueue: DispatchQueue = DispatchQueue(label: "com.orens.elevator.elevator")
    
    init(maxWeight: Double, maxFloor: Int, control: Control) {
        self.maxWeight = maxWeight
        self.maxFloor = maxFloor
        self.control = control
        super.init(name: "ELV")
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
        return "<Elevator id: \(short_id()), floor: \(floor), direction: \(direction), state: \(state), weight (max): \(weight) (\(maxWeight)), velocity: \(velocity)>"
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
        debug(message: "opening doors at floor: \(floor)...")
    }
    
    func close() {
        debug(message: "closing doors at floor: \(floor)...")
   }
    
    func arriveAtFloor(request: Request) {
        open()
        sleep(2)
        request.destinationAction?(request)
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
            
            debug(message: "moving to floor: \(floor)...")
        }
    }
};

class Control : Object {
    var elevators = [String: Elevator]()
    var requests = [Request]()
    let dispatchQueue: DispatchQueue = DispatchQueue(label: "com.orens.elevator.control")
    
    init() {
        super.init(name: "CTL")
    }
    
    func attachElevator(elevator: Elevator) {
        elevators[elevator.id] = elevator
    }
    
    func detachElevator(elevator: Elevator) {
        elevators.removeValue(forKey: elevator.id)
    }
    
    func description() -> String {
        return "<Control id: \(short_id()) number_elevators: \(elevators.count)>"
    }
    
    func callElevator(request: Request) {
        requests.append(request)
        debug(message: "control: queue request for \(request.description())")
    }
    
    private func _internalRemoveRequestByID(id: String) {
        if let i = requests.index(where: { ($0.id == id)}) {
            let value = requests.remove(at: i)
            debug(message: "clearing floor: \(floor) [\(i)] request: \(value.description())")
        }
    }
    
    private func _internalRemoveRequestsByFloor(floor: Int, direction: Direction) {
        if (floor == 0) {
            return
        }
        for request in requests {
            if (request.floor == floor && request.direction == direction) {
                _internalRemoveRequestByID(id: request.id)
            }
        }
    }
    
    private func _internalCallBestElevator(direction: Direction, floor: Int) -> Elevator? {
        // TODO send it the first elevator for now
        return elevators.first?.value
    }
    
    private func _internalProcessRequest() {
        if (!requests.isEmpty) {
            guard let next = requests.first else {
                return
            }
            
            guard let elevator = _internalCallBestElevator(direction: next.direction, floor: next.floor) else {
                print("no elevator available, please attach one")
                return
            }
            elevator.makeActive()
            var direction = Direction.Up
            if (elevator.floor > next.floor) {
                direction = Direction.Down
            }
            
            var open = false
            while (elevator.floor != next.floor) {
                // move the elevator
                elevator.move(direction: direction)

                // then determine if we should open for this floor
                for value in requests {
                    if (value.floor == elevator.floor && (value.direction == Direction.GoTo || value.direction == direction)) {
                        open = true
                        break
                    }
                }
                
                if (!open && elevator.floor == next.floor) {
                    // we are at the requested floor
                    open = true
                }
                
                if (open) {
                    elevator.arriveAtFloor(request: next)
                    if (elevator.floor == next.floor) {
                        _internalRemoveRequestByID(id: next.id)
                    }
                    _internalRemoveRequestsByFloor(floor: elevator.floor, direction: direction)
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
            while(true) {
                self._internalProcessRequest()
            }
        }
    }
}

class Building : Object {
    var floors: Int
    let control: Control = Control()
    var elevators = [Elevator]()

    init(floors: Int) {
        self.floors = floors
        elevators.append(Elevator(maxWeight: 1200, maxFloor: self.floors, control: self.control))
        for elevator in elevators {
            control.attachElevator(elevator: elevator)
        }
        control.process()
        super.init(name: "BLD")
    }
    
    func run() {
        Building.SimulateCallingElevator(control: control, delay: 3.0, floor: 3, direction: Direction.Up, destinationFloor: 4)
        Building.SimulateCallingElevator(control: control, delay: 6.0, floor: 8, direction: Direction.Down, destinationFloor: 2)
        Building.SimulateCallingElevator(control: control, delay: 9.0, floor: 1, direction: Direction.Up, destinationFloor: 9)
        Building.SimulateCallingElevator(control: control, delay: 10.0, floor: 5, direction: Direction.Up, destinationFloor: 9)
        Building.SimulateCallingElevator(control: control, delay: 12.0, floor: 5, direction: Direction.Down, destinationFloor: 1)
        Building.SimulateCallingElevator(control: control, delay: 15.0, floor: 10, direction: Direction.Down, destinationFloor: 1)
        Building.SimulateCallingElevator(control: control, delay: 18.0, floor: 3, direction: Direction.Down, destinationFloor: 1)
    }
    
    func description() -> String {
        return "<Building id: \(short_id()) floors: \(floors)>"
    }

    static func SimulateCallingElevator(control: Control, delay: Double, floor: Int, direction: Direction, destinationFloor: Int) {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + delay) {
            let request = Request(direction: direction, floor: floor, type: RequestType.Floor, block: {
                [control, destinationFloor] (original: Request) -> () in
                control.callElevator(request: Request(floor: destinationFloor, original: original))
            })
            control.callElevator(request: request)
        }
    }
}

let building = Building(floors: 10)
building.run()
Building.SimulateCallingElevator(control: building.control, delay: 22.0, floor: 10, direction: Direction.Down, destinationFloor: 5)
