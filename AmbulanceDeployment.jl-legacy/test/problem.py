class problem:
    def __init__(self, _hourly_calls, _adjacent_nbhd, _coverage, _namb):
        self.wings = 2
        self.hourly_calls = _hourly_calls
        self.adjacent_nbhd = _adjacent_nbhd
        self.coverage = _coverage
        self.namb = _namb
    #train_filter = (_hourly_calls[!,:year] .== 2019) .* (_hourly_calls[!,:month] .<= 3)
    # name=""
    # age=0
    # city=""
    # def display(self):
    #     print("Name : ",self.name)
    #     print("Age : ",self.age)
    #     print("City : ",self.city)