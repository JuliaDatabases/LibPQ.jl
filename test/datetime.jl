@testset "Datetime text precision" begin
    base = DateTime(2023, 3, 3, 12, 34, 56)
    for (fraction, milliseconds) in (
        ("", 0),
        (".7", 700),
        (".78", 780),
        (".789", 789),
        (".000999", 0),
        (".789000", 789),
        (".789012", 789),
        (".999999", 999),
    )
        text = "2023-03-03 12:34:56" * fraction
        expected = base + Millisecond(milliseconds)
        @test LibPQ.pqparse(DateTime, text) == expected
        @test LibPQ.pqparse(UTCDateTime, text * "+00") == UTCDateTime(expected)
        @test LibPQ.pqparse(ZonedDateTime, text * "+00") == ZonedDateTime(expected, tz"UTC")
    end
    @test LibPQ.pqparse(Time, "12:34:56.789") == Time(12, 34, 56, 789)
    for T in (DateTime, UTCDateTime, ZonedDateTime, Time)
        @test_throws ArgumentError LibPQ.pqparse(T, "invalid")
    end
end
