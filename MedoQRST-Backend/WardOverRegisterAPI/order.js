class Order {
    constructor(Bed_no, Ward_no, Last_update_time, Last_update_date, Last_updated_by, Update_notes) {
        this.Bed_no = Bed_no; 
        this.Ward_no = Ward_no; 
        this.Last_update_time = Last_update_time;
        this.Last_update_date = Last_update_date;
        this.Last_updated_by = Last_updated_by;
        this.Update_notes = Update_notes;
    }
}

module.exports = Order;
