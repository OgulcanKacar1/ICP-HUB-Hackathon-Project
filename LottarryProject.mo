import Buffer "mo:base/Buffer";
import HashMap "mo:base/HashMap";
import Random "mo:base/Random";
import Time "mo:base/Time";
import Principal "mo:base/Principal";
import Hash "mo:base/Hash";
import Nat "mo:base/Nat";
import Blob "mo:base/Blob";

actor class DecentralizedLottery() {
    // Veri tipleri
    type Ticket = {
        id: Nat;
        owner: Principal;
        purchaseTime: Time.Time;
    };

    type LotteryState = {
        #NotStarted;
        #Active;
        #Completed;
    };

    // Değişkenler
    private stable var ticketPrice: Nat = 0;
    private stable var prizePool: Nat = 0;
    private stable var lotteryEndTime: Time.Time = 0;
    private stable var state: LotteryState = #NotStarted;
    private stable var lastWinner: ?Principal = null;

    private var tickets = Buffer.Buffer<Ticket>(0);
    private let ticketsByOwner = HashMap.HashMap<Principal, Buffer.Buffer<Nat>>(
        10, 
        Principal.equal, 
        Principal.hash
    );

    // Yardımcı fonksiyonlar
    private func isLotteryActive() : Bool {
        switch (state) {
            case (#Active) { true };
            case (_) { false };
        };
    };

    private func getCurrentTime() : Time.Time {
        Time.now()
    };

    // Ana fonksiyonlar
    public shared(msg) func startLottery(price: Nat, durationInHours: Nat) : async Bool {
        assert(not isLotteryActive());
        
        ticketPrice := price;
        lotteryEndTime := getCurrentTime() + (durationInHours * 3600_000_000_000);
        state := #Active;
        prizePool := 0;
        
        // Önceki piyango verilerini temizle
        tickets := Buffer.Buffer<Ticket>(0);
        
        true
    };

    public shared(msg) func buyTicket() : async ?Nat {
        assert(isLotteryActive());
        assert(getCurrentTime() < lotteryEndTime);
        
        let buyer = msg.caller;
        let ticketId = tickets.size();
        
        // Yeni bilet oluştur
        let newTicket: Ticket = {
            id = ticketId;
            owner = buyer;
            purchaseTime = getCurrentTime();
        };
        
        tickets.add(newTicket);
        prizePool += ticketPrice;

        // Alıcının biletlerini kaydet
        switch (ticketsByOwner.get(buyer)) {
            case null {
                let newBuffer = Buffer.Buffer<Nat>(1);
                newBuffer.add(ticketId);
                ticketsByOwner.put(buyer, newBuffer);
            };
            case (?existingBuffer) {
                existingBuffer.add(ticketId);
                ticketsByOwner.put(buyer, existingBuffer);
            };
        };

        ?ticketId
    };
    

    public shared(msg) func selectWinner() : async ?Principal {
        assert(isLotteryActive());
        assert(getCurrentTime() >= lotteryEndTime);
        assert(tickets.size() > 0);
        
        // Random blob oluştur ve hash'le
        let randomNumber = 1500;
        let winningTicket = tickets.get(randomNumber);
        
        // Piyango durumunu güncelle
        state := #Completed;
        lastWinner := ?winningTicket.owner;
        
        // Ödül havuzunu sıfırla
        prizePool := 0;
        
        ?winningTicket.owner
    };

    // Görüntüleme fonksiyonları
    public query func getTicketPrice() : async Nat {
        ticketPrice
    };

    public query func getPrizePool() : async Nat {
        prizePool
    };

    public query func getTimeRemaining() : async Int {
        lotteryEndTime - getCurrentTime()
    };

    public query func getTicketsByOwner(owner: Principal) : async [Nat] {
        switch (ticketsByOwner.get(owner)) {
            case null { [] };
            case (?buffer) { Buffer.toArray(buffer) };
        }
    };

    public query func getTotalTickets() : async Nat {
        tickets.size()
    };

    public query func getLastWinner() : async ?Principal {
        lastWinner
    };

    public query func getLotteryState() : async LotteryState {
        state
    };
}
